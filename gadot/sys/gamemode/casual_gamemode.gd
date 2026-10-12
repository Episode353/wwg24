extends Node

# Casual: two teams, last team with someone alive wins the round, empty slots are filled with bots.
# The server runs the state machine, every peer mirrors the state for the HUD.

enum State { WARMUP, LIVE, ROUND_END, MATCH_END }

const TEAM_NONE: int = 0
const TEAM_A: int = 1
const TEAM_B: int = 2
const ROUND_END_TIME: float = 5.0
const MATCH_END_TIME: float = 10.0
const ALIVE_CHECK_INTERVAL: float = 0.25
const STATE_SYNC_INTERVAL: float = 1.0
const BOT_WEAPONS: Array[String] = ["ak47", "shotgun", "rocket_launcher"]
const BOT_WEAPON_RANGE: String = "25"
const HUD_LABEL_SETTINGS = preload("res://fonts/hud_labels.tres")
const TOP_BAR = preload("res://sys/hud/casual_top_bar.gd")
# Warmup seconds remaining that get a center screen countdown message
const COUNTDOWN_ANNOUNCE_SECONDS: Array[int] = [60, 30, 20, 10, 5, 4, 3, 2, 1]
const WON_COLOR := Color(0.45, 1.0, 0.45)
const LOST_COLOR := Color(1.0, 0.4, 0.4)

var rounds: int = 5
var players_per_team: int = 4
var waiting_for_players: int = 10
var friendly_fire: bool = false

var state: State = State.WARMUP
var time_left: float = 0.0
var round_time: float = 0.0 # Seconds since the current round went live, counts up
var current_round: int = 0
var score_a: int = 0
var score_b: int = 0
var last_round_winner: int = TEAM_NONE
# Rolled by the server every round so every peer shuffles spawn slots the same way
var spawn_seed: int = 0
# Human player node name -> team. Bots carry their team from add_bot.
var teams: Dictionary = {}

var _alive_check_timer: float = 0.0
var _sync_timer: float = 0.0
var _hud_label: Label
var _top_bar: Control
# What the center screen messages last showed, so every peer announces each change once
var _announced_state: int = -1
var _announced_round: int = -1
var _announced_second: int = -1
# Clients only get RPCs once their own Gamemode node exists (they announce it with request_state)
var _synced_peers: Array[int] = []

@onready var world = get_parent()


func configure(definition: Node) -> void:
	rounds = max(1, definition.rounds)
	players_per_team = max(1, definition.players_per_team)
	waiting_for_players = max(0, definition.waiting_for_players)
	friendly_fire = definition.friendly_fire != 0
	print("Casual gamemode: rounds=%d players_per_team=%d warmup=%ds friendly_fire=%s" % [rounds, players_per_team, waiting_for_players, friendly_fire])


func _ready() -> void:
	_create_hud_label()
	if multiplayer.is_server():
		_server_start_warmup()
	else:
		rpc_id(1, "request_state")


func _exit_tree() -> void:
	if is_instance_valid(_hud_label):
		_hud_label.queue_free()
	if is_instance_valid(_top_bar):
		_top_bar.queue_free()


func _process(delta: float) -> void:
	time_left = max(time_left - delta, 0.0)
	if state == State.LIVE:
		round_time += delta
	if multiplayer.is_server():
		_server_tick(delta)
	_update_hud()
	_update_announcements()


# ============================================================================
# Queries used by world.gd, Player.gd and bot_logic.gd
# ============================================================================
func register_player(player: Node) -> void:
	var player_name := str(player.name)
	if teams.has(player_name):
		player.team = teams[player_name]
		return
	if player.is_bot or not multiplayer.is_server():
		return
	var team: int = _random_team() if state == State.WARMUP else _smaller_team()
	teams[player_name] = team
	player.team = team
	_broadcast_teams.call_deferred()
	if state != State.WARMUP:
		# Joined mid-match: sit out as a ghost until the next round
		_ghost_late_joiner.call_deferred(player_name)


func unregister_player(player_name: String) -> void:
	teams.erase(player_name)
	_synced_peers.erase(player_name.to_int())


# True when the gamemode takes over the death (player becomes a ghost instead of respawning)
func handle_death(player: Node) -> bool:
	return player.team != TEAM_NONE and state != State.WARMUP


func allows_manual_respawn() -> bool:
	return state == State.WARMUP


func can_damage(attacker_name: String, victim: Node) -> bool:
	if friendly_fire or attacker_name == "" or attacker_name == str(victim.name):
		return true
	var attacker: Node = world.get_node_or_null(attacker_name)
	if attacker == null or not "team" in attacker:
		return true
	return not is_teammate(attacker, victim)


func is_teammate(a: Node, b: Node) -> bool:
	return a.team != TEAM_NONE and a.team == b.team


# x = alive players on this team, y = alive players on the other team
func get_alive_counts(team: int) -> Vector2i:
	var counts := Vector2i.ZERO
	for p in _get_players():
		if p.is_dead or p.team == TEAM_NONE:
			continue
		if p.team == team:
			counts.x += 1
		else:
			counts.y += 1
	return counts


# x = alive players on the team, y = total players on the team (bots included)
func _team_alive_and_total(team: int) -> Vector2i:
	var counts := Vector2i.ZERO
	for p in _get_players():
		if p.team != team:
			continue
		counts.y += 1
		if not p.is_dead:
			counts.x += 1
	return counts


# Average position of a team's spawn points, used by bots as the "enemy base" / "home"
func get_spawn_center(team: int) -> Vector3:
	var group := "team_a_spawn" if team == TEAM_A else "team_b_spawn"
	var total := Vector3.ZERO
	var count := 0
	for spawn in get_tree().get_nodes_in_group(group):
		if not spawn.is_queued_for_deletion():
			total += spawn.global_position
			count += 1
	return total / count if count > 0 else Vector3.ZERO


func get_spawn_point(player: Node) -> Node3D:
	var group := "team_a_spawn" if player.team == TEAM_A else "team_b_spawn"
	var spawns: Array = []
	for spawn in get_tree().get_nodes_in_group(group):
		if not spawn.is_queued_for_deletion():
			spawns.append(spawn)
	if spawns.is_empty():
		push_warning("No '%s' entities in map, spawning %s at origin." % [group, player.name])
		return null
	spawns.sort_custom(func(a, b): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)

	# Same slot on every peer: sort, then shuffle with the synced seed so humans and bots get no priority
	var members: Array = []
	for p in _get_players():
		if p.team == player.team:
			members.append(str(p.name))
	if not members.has(str(player.name)):
		members.append(str(player.name))
	members.sort()
	_seeded_shuffle(spawns, spawn_seed)
	_seeded_shuffle(members, spawn_seed + 1)
	var slot: int = members.find(str(player.name)) % spawns.size()
	return spawns[slot]


# Replaces the player's weapons: every weapon in warmup, otherwise exactly what the spawn point lists
func apply_loadout(player: Node, spawn: Node3D) -> void:
	if not player.is_node_ready():
		# Weapons_Manager builds its weapon list in _ready
		player.ready.connect(apply_loadout.bind(player, spawn), CONNECT_ONE_SHOT)
		return
	var weapons_manager: Node = player.weapons_manager
	var loadout: Array = []
	if state == State.WARMUP:
		loadout = weapons_manager.weapon_list.keys()
	elif is_instance_valid(spawn):
		loadout = spawn.get_weapon_names()

	var equip := ""
	if player.is_bot:
		equip = player.bot_logic.pick_spawn_weapon(loadout)
	weapons_manager.set_loadout(loadout, equip)


# Called by world.gd before this gamemode is replaced (map change / rebuild)
func cleanup() -> void:
	for p in _get_players():
		if p.is_bot and p.team != TEAM_NONE:
			if multiplayer.is_server():
				p.queue_free()
			continue
		if p.is_dead:
			p.revive()
		p.team = TEAM_NONE


# ============================================================================
# Server state machine
# ============================================================================
func _server_tick(delta: float) -> void:
	match state:
		State.WARMUP:
			if time_left <= 0.0:
				_server_start_match()
		State.LIVE:
			_alive_check_timer += delta
			if _alive_check_timer >= ALIVE_CHECK_INTERVAL:
				_alive_check_timer = 0.0
				_server_check_round_over()
		State.ROUND_END:
			if time_left <= 0.0:
				if current_round >= rounds:
					_server_end_match()
				else:
					_server_start_round()
		State.MATCH_END:
			if time_left <= 0.0:
				_server_start_warmup()

	_sync_timer += delta
	if _sync_timer >= STATE_SYNC_INTERVAL:
		_sync_timer = 0.0
		_broadcast_state()


func _server_start_warmup() -> void:
	_server_remove_all_bots()
	teams.clear()
	for p in _get_humans():
		teams[str(p.name)] = _random_team()
	_broadcast_teams()

	state = State.WARMUP
	time_left = waiting_for_players
	current_round = 0
	score_a = 0
	score_b = 0
	last_round_winner = TEAM_NONE
	spawn_seed = randi()
	_broadcast_state()
	_send_to_all("_respawn_everyone")


func _server_start_match() -> void:
	# Deal shuffled humans out alternately so an odd count leaves one extra on a random team
	teams.clear()
	var humans := _get_humans()
	humans.shuffle()
	var next_team := _random_team()
	for p in humans:
		teams[str(p.name)] = next_team
		next_team = _other_team(next_team)
	_broadcast_teams()

	current_round = 0
	score_a = 0
	score_b = 0
	_server_start_round()


func _server_start_round() -> void:
	current_round += 1
	_server_fill_bots()
	state = State.LIVE
	time_left = 0.0
	round_time = 0.0
	_alive_check_timer = 0.0
	spawn_seed = randi()
	_broadcast_state()
	_send_to_all("_respawn_everyone")


func _server_fill_bots() -> void:
	for team in [TEAM_A, TEAM_B]:
		var humans := 0
		var bots: Array = []
		for p in _get_players():
			if p.team != team:
				continue
			if p.is_bot:
				bots.append(p)
			else:
				humans += 1
		var wanted_bots: int = max(players_per_team - humans, 0)
		while bots.size() > wanted_bots:
			bots.pop_back().queue_free()
		for i in wanted_bots - bots.size():
			world.rpc("add_bot", "0 0 0", false, BOT_WEAPON_RANGE, BOT_WEAPONS.pick_random(), false, Vector3.ZERO, team)


# Bots live on the server, the MultiplayerSpawner removes them on the clients
func _server_remove_all_bots() -> void:
	for p in _get_players():
		if p.is_bot and p.team != TEAM_NONE:
			p.queue_free()


func _server_check_round_over() -> void:
	var alive := {TEAM_A: 0, TEAM_B: 0}
	for p in _get_players():
		if alive.has(p.team) and not p.is_dead:
			alive[p.team] += 1
	if alive[TEAM_A] > 0 and alive[TEAM_B] > 0:
		return

	var winner := TEAM_NONE
	if alive[TEAM_A] > 0:
		winner = TEAM_A
		score_a += 1
	elif alive[TEAM_B] > 0:
		winner = TEAM_B
		score_b += 1
	last_round_winner = winner
	state = State.ROUND_END
	time_left = ROUND_END_TIME
	_broadcast_state()
	print("Round %d over: %s" % [current_round, _round_result_text()])


func _server_end_match() -> void:
	state = State.MATCH_END
	time_left = MATCH_END_TIME
	_broadcast_state()
	print("Match over: %s" % _match_result_text())


func _ghost_late_joiner(player_name: String) -> void:
	_send_to_all("_make_ghosts", [[player_name]])


# ============================================================================
# Networking
# ============================================================================
# Runs the method locally, then on every client that has its Gamemode node ready
func _send_to_all(method: StringName, args: Array = []) -> void:
	callv(method, args)
	var peers := multiplayer.get_peers()
	for peer in _synced_peers:
		if peer in peers:
			callv("rpc_id", [peer, method] + args)


func _broadcast_state() -> void:
	_send_to_all("_apply_state", [state, time_left, round_time, current_round, score_a, score_b, last_round_winner, spawn_seed])


func _broadcast_teams() -> void:
	_send_to_all("_apply_teams", [teams])


@rpc("any_peer", "call_remote", "reliable")
func request_state() -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if not _synced_peers.has(peer):
		_synced_peers.append(peer)
	rpc_id(peer, "_apply_teams", teams)
	rpc_id(peer, "_apply_state", state, time_left, round_time, current_round, score_a, score_b, last_round_winner, spawn_seed)
	var dead: Array = []
	for p in _get_players():
		if p.is_dead:
			dead.append(str(p.name))
	rpc_id(peer, "_make_ghosts", dead)


@rpc("authority", "call_remote", "reliable")
func _apply_state(new_state: int, new_time_left: float, new_round_time: float, new_round: int, new_score_a: int, new_score_b: int, new_last_winner: int, new_spawn_seed: int) -> void:
	state = new_state as State
	time_left = new_time_left
	round_time = new_round_time
	current_round = new_round
	score_a = new_score_a
	score_b = new_score_b
	last_round_winner = new_last_winner
	spawn_seed = new_spawn_seed


@rpc("authority", "call_local", "reliable")
func _apply_teams(new_teams: Dictionary) -> void:
	teams = new_teams
	for p in _get_humans():
		p.team = teams.get(str(p.name), TEAM_NONE)


@rpc("authority", "call_local", "reliable")
func _respawn_everyone() -> void:
	for p in _get_players():
		if p.is_bot and p.team == TEAM_NONE:
			continue
		p.revive()
		world.spawn_player(p)
		if p.is_bot:
			p.bot_logic.start_round_plan()


@rpc("authority", "call_local", "reliable")
func _make_ghosts(player_names: Array) -> void:
	for player_name in player_names:
		var p: Node = world.get_node_or_null(str(player_name))
		if p and "is_dead" in p and not p.is_dead:
			p.enter_ghost()


# ============================================================================
# Helpers
# ============================================================================
func _get_players() -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group("players"):
		if node is CharacterBody3D and "team" in node and not node.is_queued_for_deletion():
			result.append(node)
	return result


func _get_humans() -> Array:
	return _get_players().filter(func(p): return not p.is_bot)


func _random_team() -> int:
	return TEAM_A if randi() % 2 == 0 else TEAM_B


func _seeded_shuffle(items: Array, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp


func _other_team(team: int) -> int:
	return TEAM_B if team == TEAM_A else TEAM_A


func _smaller_team() -> int:
	var count := {TEAM_A: 0, TEAM_B: 0}
	for p in _get_humans():
		if count.has(p.team):
			count[p.team] += 1
	if count[TEAM_A] == count[TEAM_B]:
		return _random_team()
	return TEAM_A if count[TEAM_A] < count[TEAM_B] else TEAM_B


func _team_name(team: int) -> String:
	match team:
		TEAM_A:
			return "Wizards"
		TEAM_B:
			return "Humans"
	return "No team"


func _score_text() -> String:
	return "%s %d - %d %s" % [_team_name(TEAM_A), score_a, score_b, _team_name(TEAM_B)]


func _round_result_text() -> String:
	if last_round_winner == TEAM_NONE:
		return "Round draw"
	return "%s win the round" % _team_name(last_round_winner)


func _match_result_text() -> String:
	if score_a == score_b:
		return "Match tied %d - %d" % [score_a, score_b]
	return "%s win the match %d - %d" % [_team_name(TEAM_A if score_a > score_b else TEAM_B), max(score_a, score_b), min(score_a, score_b)]


# ============================================================================
# HUD (debug text under the FPS / nodes / frame time labels)
# ============================================================================
func _create_hud_label() -> void:
	var hud: Node = world.get_node_or_null("CanvasLayer/HUD")
	if hud:
		_top_bar = TOP_BAR.new()
		hud.add_child(_top_bar)
		_top_bar.set_teams(_team_name(TEAM_A), Globals.TEAM_COLORS[TEAM_A], _team_name(TEAM_B), Globals.TEAM_COLORS[TEAM_B])

	var log_box: Node = world.get_node_or_null("CanvasLayer/HUD/LOG")
	if log_box == null:
		push_warning("CanvasLayer/HUD/LOG not found, gamemode HUD disabled.")
		return
	_hud_label = Label.new()
	_hud_label.name = "GamemodeInfo"
	_hud_label.label_settings = HUD_LABEL_SETTINGS
	_hud_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	log_box.add_child(_hud_label)


# ============================================================================
# Center screen messages
# ============================================================================
func _update_announcements() -> void:
	if state != _announced_state or current_round != _announced_round:
		_announced_state = state
		_announced_round = current_round
		_announced_second = int(ceil(time_left))
		_announce_state()
		return
	if state == State.WARMUP:
		var seconds := int(ceil(time_left))
		if _announced_second <= 0 and seconds > 0:
			# A client that just joined: the real warmup time arrived with the first state sync
			_announced_second = seconds
			_announce_countdown(seconds)
		elif seconds < _announced_second:
			# Only counting down: a state sync can nudge time_left back up a little
			_announced_second = seconds
			if seconds in COUNTDOWN_ANNOUNCE_SECONDS:
				_announce_countdown(seconds)


func _announce_state() -> void:
	match state:
		State.WARMUP:
			_announce_countdown(int(ceil(time_left)))
		State.LIVE:
			world.show_announcement("ROUND %d" % current_round, "of %d - fight!" % rounds)
		State.ROUND_END:
			var title := "ROUND DRAW"
			var color := Color.WHITE
			var local_team := _local_team()
			if last_round_winner != TEAM_NONE:
				if local_team == TEAM_NONE:
					title = "%s WIN THE ROUND" % _team_name(last_round_winner).to_upper()
				elif local_team == last_round_winner:
					title = "ROUND WON"
					color = WON_COLOR
				else:
					title = "ROUND LOST"
					color = LOST_COLOR
			world.show_announcement(title, _score_text(), color, ROUND_END_TIME - 1.5)
		State.MATCH_END:
			var title := "DRAW"
			var color := Color.WHITE
			var local_team := _local_team()
			if score_a != score_b:
				var winner := TEAM_A if score_a > score_b else TEAM_B
				if local_team == TEAM_NONE:
					title = "%s WIN" % _team_name(winner).to_upper()
				elif local_team == winner:
					title = "VICTORY"
					color = WON_COLOR
				else:
					title = "DEFEAT"
					color = LOST_COLOR
			world.show_announcement(title, _match_result_text(), color, MATCH_END_TIME - 2.0)


func _announce_countdown(seconds: int) -> void:
	if seconds <= 0:
		return
	var subtitle := "%d second%s remaining" % [seconds, "" if seconds == 1 else "s"]
	world.show_announcement("WAITING FOR PLAYERS", subtitle, Color.WHITE, 0.6 if seconds <= 5 else 2.0)


func _local_team() -> int:
	var me: Node = world.get_node_or_null(str(multiplayer.get_unique_id()))
	if me and "team" in me:
		return me.team
	return TEAM_NONE


func _update_top_bar() -> void:
	if not is_instance_valid(_top_bar):
		return
	_top_bar.set_scores(score_a, score_b)
	_top_bar.set_alive(_team_alive_and_total(TEAM_A), _team_alive_and_total(TEAM_B))
	var countdown := int(ceil(time_left))
	var round_text := "ROUND %d / %d" % [current_round, rounds]
	match state:
		State.WARMUP:
			_top_bar.set_center("%d ROUNDS" % rounds, countdown, "WAITING FOR PLAYERS")
		State.LIVE:
			_top_bar.set_center(round_text, int(round_time), "")
		State.ROUND_END:
			_top_bar.set_center(round_text, countdown, "MATCH ENDING" if current_round >= rounds else "NEXT ROUND")
		State.MATCH_END:
			_top_bar.set_center("MATCH OVER", countdown, "RESTARTING")


func _update_hud() -> void:
	_update_top_bar()
	if not is_instance_valid(_hud_label):
		return
	var seconds := int(ceil(time_left))
	var lines: PackedStringArray = []
	match state:
		State.WARMUP:
			lines.append("CASUAL | WARMUP | match starts in %d" % seconds)
		State.LIVE:
			lines.append("CASUAL | ROUND %d/%d | LIVE" % [current_round, rounds])
		State.ROUND_END:
			lines.append("CASUAL | ROUND %d/%d | %s | next round in %d" % [current_round, rounds, _round_result_text(), seconds])
		State.MATCH_END:
			lines.append("CASUAL | MATCH OVER | %s | restarting in %d" % [_match_result_text(), seconds])
	lines.append("SCORE  %s | Friendly fire: %s" % [_score_text(), "ON" if friendly_fire else "OFF"])

	var local_name := str(multiplayer.get_unique_id())
	for team in [TEAM_A, TEAM_B]:
		lines.append(_team_hud_line(team, local_name))

	var me: Node = world.get_node_or_null(local_name)
	if me and "team" in me:
		var status := "DEAD - free fly spectating until next round" if me.is_dead else "ALIVE"
		lines.append("You: %s | %s" % [_team_name(me.team), status])
	_hud_label.text = "\n".join(lines)


func _team_hud_line(team: int, local_name: String) -> String:
	var entries: PackedStringArray = []
	var alive := 0
	var total := 0
	for p in _get_players():
		if p.team != team:
			continue
		total += 1
		var entry := str(p.name)
		if p.is_bot:
			entry = "bot " + entry
		elif entry == local_name:
			entry += " (you)"
		if p.is_dead:
			entry += " [dead]"
		else:
			alive += 1
		entries.append(entry)
	return "%s (%d/%d alive): %s" % [_team_name(team), alive, total, ", ".join(entries)]
