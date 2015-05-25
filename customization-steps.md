# Steps to install

## 1/ Install Ubuntu as per normal

Just follow a standard Ubuntu installation with the variant of your choice. Recommendations are:

* Lubuntu (i386/i686/"32-bit" variant) - very lightweight Linux operating system for reviving old machines
* Ubuntu MATE - another lightweight Ubuntu variant, for a classic desktop experience that's easy to use
* Ubuntu - the standard distribution with the Unity interface

## 2/ Install Our-PXE and its tools

You need to be connected to the Internet for the next steps.

Once booted into the freshly installed system, some initial technical preparation needs to be done to install the easy-install tools.

Open a browser and download the following: http://helpuse.com/download/partimus.tar

Save the file to your Downloads folder in your home folder. Go to your downloads folder in your normal folder explorer, right-click on the partimus.tar folder, and choose "Extract here"

Open a terminal by using the keyboard shortcut [Ctrl + Alt + T] and then type the following lines, presing the Return key for each new line:

	cd Downloads
	./partimus-setup.sh

Some messages will fly by on the screen; once you see the message saying that setup is finished, you can close the terminal.

You can now customize the system's look and feel, and install any application syou want for the final system.

The following instructions work for Lubuntu - adapt to your chosen system as needed:

* To change the desktop background, right-click on the desktop and choose "Desktop preferences"
* To change other appearances of the system
	* go to the Start menu in the bottom left of the screen
	* choose the Preferences menu
	* Choose an item from that menu to customize
* To install software
	* Go to the Start menu in the bottom left of the screen
	* choose the System Tools
	* Choose the "Lubuntu Software Centre"

Note: if you want to set your own desktop background that every user in the new system will have when they first are created,
	* download the wallpaper picture you want;
	* save the picture to : File System (choose this in the list on the left): partimus
	* then customize your desktop background to use that same file.

[insert screenshots]

## 3/ Create the custom installation CD

On your desktop there is a program called "Make Partimus CD" - open it to launch the creation process. [if a progress terminal does not open to show you current activity, it will look like nothing is happening; open a terminal and run `tail -f /var/log/respin.log` to see what's happening]

When the CD is ready, you will see a window open where the CD's .ISO file has been created.

You will also see the respin.log report on your desktop.

You can now burn this ISO file to a writable DVD using the Brasero application installed in your Applications menu.
