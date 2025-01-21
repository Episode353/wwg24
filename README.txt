A Multiplayer Gadot game using (UDP Protocol)
Multiplayer Based off of: (https://youtu.be/n8D3vEx7NAE)
Stair Stepping Based off of: (https://www.youtube.com/watch?v=Tb-R3l0SQdc)
The Multiplayer Server pinging was based off of (https://github.com/Brandt-J/GodotServerBrowser)

To host a server: 
Open wizards-with-guns.console.exe, which should launch the game and a console window.
Click host, in the console window the server IP adress should print out, you can share this with your friends.
They can type it into the server Ip Adress bar and hit join

How to Make Maps:	
Open trenchbroom/TrenchBroom.exe
Save maps to the tbmaps folder
the game compiles the map when loading it, so you dont need to restart the game when/
	making maps, you can just disconnect and reconnect
Make sure the texture folders trenchbroom uses and the texture folders godot uses are the same/
	or there will be some missing textures

How to edit your Keybinds.
Edit the autoexec.json

How to edit your Configs
Edit the config.json

Made with Godot_v4.3-stable_win64.exe

----------------------------------------------------------------
Features to add:

	Menus
		- Settings Menu that will save and load data to/from the config.txt
		- Should be openable from a settings icon on the main menu or pause menu
		- Custom Player Color
		- Visual settings, such as anti aliasing, resolution, etc
		- Edit Username
			- Should be a "Username" in the config.txt that is used for the players username
			- Have a hardcoded default, that if not changed will let the game choose a random one
			from a predetermined list, and not let there be duplicates
		- Scoreboard
		- Replace Sprite Charachter with Low Poly Wizard
			- Model has Customizable Color, use shader from: http://y2u.be/sCZFttl8TZk
	Console:
		- Add Disconnect Command
		- Add Load Map Command


	Maps:
		- Single PLayer Shooting range
			- Make entities that look like a shooting range dummy and play an animation when shot, so they can be used in trenchbroom
			-making more entitites would be cool for those maps, and the sooner we make the entities the more they can be used in maps / 
			as we build more maps
		- "Tutorial Map" which is a on rails map where signs say "use this button to do this"
			and then has a scenario which you need to do the thing to get past
			- This would benefit if it had the shooting range enimies from the shooting range map

	Objects:
		- Grabbable objects
			Objects in "Grabbable group" can be picked up with e and also placed down
	Weapons:
	- Magic wand weapon?
	- A guitar that shoots musicv as bullet gun, reload the gun by cocking the frettboard from the neck to the bodty and when shooting the effeftrs come from the nck of the guitar
	- Another movement based weapon like the rocket launcher would be really cool
	-Portal Gun
	- The Power
		- has a number of different effects such as low gravity or resistance
		- only one effect can be active at a time

	Website:
		- Would be cool if there was a page to upload user created maps that could be added to the game


Bugs to fix:
	- The player name entered in the config.txt appears over enemy players, which is wrong. It should appear over the player who has it entered in the config.
	- Sound
	- Older computers have an error and require starting the game in opengl 3, which will cause issues
	- some computers are unable to join / host a game due to networking issues
	- Awkward stuttery movement when walking close to wall
	- If you enter a ip adress wrong, or no server is found, display/
	 message and go back to main menu, or maybe Display a message educating/
	 the player on what UDP is and their router might have it be disabled
----------------------------------------------------------------
