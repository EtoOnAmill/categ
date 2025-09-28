categ is a program to organize data through tags; you can use it for files, directories, ideas, or anything text based at all!

**TODO** rn everything is hard coded
categ utilizes very few enviroment variables for it's operation:
HOME : the user home dir, used for the TAGGY_DIR user path
USER : the username, used to name the database file
CATEG_DIR : defaults to `~/.local/share/categ/` if run normally or defaults to `/var/local/categ/` if the program is started as a daemon. It contains the database for tag and any other data for the correct functioning of the program.


DEPENDENCIES
categ uses sqlite3, gcc, gnu guile, and gnu make

BUILDING & INSTALLING
Enter the repository root directory use the following comand to build
make all

To install we'll wait for when the program is ready >wO
