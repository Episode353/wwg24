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
	- Make certain objects be destroyed when theyre shot
		Make it so if you shoot a rocket it will explode mid air
	- Single PLayer Shooting range
		- Make entities that look like a shooting range dummy and play an animation when shot, so they can be used in trenchbroom
		-making more entitites would be cool for those maps, and the sooner we make the entities the more they can be used in maps / 
		as we build more maps
	- Scoreboard
	- Usernames
	- Replace Sprite Charachter with Low Poly Wizard
		- Model has Customizable Color, use shader from: http://y2u.be/sCZFttl8TZk
	- Server Browser
	- Settings Menu that will save and load data to/from the config.txt
		- Custom Player Color
		- Edit Username
		- Fov Adjustment
	- Magic wand weapon?
	- Keyboard
		- Remake model with movable keys so each button press can move the key and play a noise
	- Improve the pause menu
	- Improve the home screen, have a background level be loaded in for a background for the
	menus to be ontop of like in half-life2, and add a logo
	- A guitar that shoots musicv as bullet gun, reload the gun by cocking the frettboard from the neck to the bodty and when shooting the effeftrs come from the nck of the guitar

Bugs to fix:
	- Older computers have an error and require starting the game in opengl 3, which will cause issues
	- some computers are unable to join / host a game due to networking issues
	- Prevent input to charachter controller when game is paused
	- Awkward stuttery movement when walking close to wall
	- If you enter a ip adress wrong, or no server is found, display/
	 message and go back to main menu, or maybe Display a message educating/
	 the player on what UDP is and their router might have it be disabled
----------------------------------------------------------------
