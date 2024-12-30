A Multiplayer Gadot game using (UDP Protocol)
Multiplayer Based off of: (https://youtu.be/n8D3vEx7NAE)

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
	- Single PLayer Shooting range
	- Scoreboard
	- Usernames
	- Replace Sprite Charachter with Low Poly Wizard
		- Model has Customizable Color, use shader from: http://y2u.be/sCZFttl8TZk
	- Server Browser
	- Settings Menu that will save and load data to/from the config.txt
		- Custom Player Color
		- Edit Username
		- Fov Adjustment
	- Magic wand
	- Keyboard
		- Remake model with movable keys so each button press can move the key and play a noise
	- Improve the pause menu
	- Improve the home screen, have a background level be loaded in for a background for the
	menus to be ontop of like in half-life2, and add a logo

Bugs to fix:
	- Prevent input to charachter controller when game is paused
	- Awkward stuttery movement when walking close to wall
	- If you enter a ip adress wrong, or no server is found, display/
	 message and go back to main menu, or maybe Display a message educating/
	 the player on what UDP is and their router might have it be disabled
----------------------------------------------------------------