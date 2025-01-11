A Multiplayer Gadot game using (UDP Protocol)
Multiplayer Based off of: (https://youtu.be/n8D3vEx7NAE)
Stair Stepping Based off of: (https://www.youtube.com/watch?v=Tb-R3l0SQdc)

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

How to edit your settings.
Edit the config.txt

Made with Godot_v4.2.2-stable_win64.exe

----------------------------------------------------------------
Features to add:

	Menus
		- Settings Menu that will save and load data to/from the config.txt
		- Should be openable from a settings icon on the main menu or pause menu
		- Should console be open by default when opening pause menu?
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
		- When opening console via console button, have the console be selected so the user can type without clicking into it
		- Console cant be opened on main menu, it should be able to
		- Add Disconnect Command
		- Add Load Map Command

	Objects:
		- Rework the mana and health drops so that they will respawn after a duration

	Maps:
		- Single PLayer Shooting range
			- Make entities that look like a shooting range dummy and play an animation when shot, so they can be used in trenchbroom
			-making more entitites would be cool for those maps, and the sooner we make the entities the more they can be used in maps / 
			as we build more maps
		- "Tutorial Map" which is a on rails map where signs say "use this button to do this"
			and then has a scenario which you need to do the thing to get past
			- This would benefit if it had the shooting range enimies from the shooting range map
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
		- Some sort of server list where when you make a server it pings the website and the website adds it to a list
		- The game can then ping the website and request the list, which will sorta be a list of all available servers
		- Whenever the list is pinged it would be useful if the website could ping the connection and see if there is a game on the port, so the server list isnt full of a buch of closed servers
		(Will be based off of this project)
		(https://www.youtube.com/watch?v=x-PF_EZI2ZM)
		(https://github.com/Brandt-J/GodotServerBrowser)

Bugs to fix:
	- Whatever name the current player has, all players have it above their head
	- Make healt and mana respawn
	- Sound
	- Dont make escape close the game
	- Viewmodel (floating gun)
	- Older computers have an error and require starting the game in opengl 3, which will cause issues
	- some computers are unable to join / host a game due to networking issues
	- Awkward stuttery movement when walking close to wall
	- If you enter a ip adress wrong, or no server is found, display/
	 message and go back to main menu, or maybe Display a message educating/
	 the player on what UDP is and their router might have it be disabled
----------------------------------------------------------------
