import std.stdio;
import std.file;
import etc.c.sqlite3;
import std.getopt;
import std.process;

int main(string[] args) {
    bool daemon_mode = false;
    getopt(args, "daemon", &daemon_mode);

    string default_dir;
    if(daemon_mode) {
        default_dir = "/var/local/taggy";
    } else {
        string home_dir = environment.get("HOME");
        if(home_dir == "") { return RETURN_CODES.NO_HOME_ENV_VARIABLE; }
        default_dir = home_dir ~ "/.local/taggy";
    }

    string taggy_dir =  environment.get("TAGGY_DIR", default_dir);
    if( !exists(taggy_dir) ) {
        try {
            mkdir(taggy_dir);
            writeln("Directory ", taggy_dir, " didn't exist and was created");
        }
        catch (Exception e) {
            stderr.writef("Unable to create directory %s\n", taggy_dir);
            return RETURN_CODES.UNABLE_TO_CREATE_TAGGY_DIR;
        }
    }

    if( !isDir(taggy_dir) ) {
        stderr.writef("%s is not a directory\n", taggy_dir);
        return RETURN_CODES.TAGGY_DIR_NOT_A_DIR;
    }

    string username = environment.get("USER");
    if(username == "") { return RETURN_CODES.NO_USERNAME_ENV_VARIABLE; }

    string database_name = taggy_dir ~ "/" ~ username ~ ".db";
    writeln("Opening database ", database_name);
    sqlite3 * database_connection;
    auto open_code = sqlite3_open_v2(
        cast(const(char*))database_name,
        &database_connection,
        SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
        null);
    scope(exit) sqlite3_close(database_connection);


    if( open_code ) {
        stderr.writef("Unable to open the sqlite database; error code : %s\n", open_code);
        return RETURN_CODES.UNABLE_TO_CREATE_TAGGY_DB;
    }

    return RETURN_CODES.OK;
}

enum RETURN_CODES {
    OK,
    UNABLE_TO_CREATE_TAGGY_DIR,
    UNABLE_TO_CREATE_TAGGY_DB,
    TAGGY_DIR_NOT_A_DIR,
    NO_HOME_ENV_VARIABLE,
    NO_USERNAME_ENV_VARIABLE,
}
