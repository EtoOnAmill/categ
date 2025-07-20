Taggy is a program to organize data through tags; you can use it for files, directories, ideas, or anything text based at all!

It operates through a sqlite database to hold all it's data so there is no risk of loosing data accidentaly. This also means that backups are super easy! Just copy the database file!


Taggy utilizes very few enviroment variables for it's operation:
HOME : the user home dir, used for the TAGGY_DIR user path
USER : the username, used to name the database file
TAGGY_DIR : defaults to `~/.local/share/taggy/` if run normally or defaults to `/var/local/taggy/` if the program is started as a daemon. It contains the database for tag and any other data for the correct functioning of the program.


Taggy can do the following things:
- track directories for changes and automatically update it's database accordingly
- creating tmp directories for the result of queries 
- run as a daemon to improve responsiveness
- recognize moved/deleted/renamed files and directories and updating it's database based on user configuration


DEPENDENCIES
Taggy uses sqlite3, dmd+phobos, and gnu make


BUILDING & INSTALLING
Enter the repository root directory use the following comand to build
make all

And the following comand to install
make install
