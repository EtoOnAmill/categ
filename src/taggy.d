import std.stdio;
import std.array;
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
        if(home_dir == "") { return Return_codes.NO_HOME_ENV_VARIABLE; }
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
            return Return_codes.UNABLE_TO_CREATE_TAGGY_DIR;
        }
    }

    if( !isDir(taggy_dir) ) {
        stderr.writef("%s is not a directory\n", taggy_dir);
        return Return_codes.TAGGY_DIR_NOT_A_DIR;
    }

    string username = environment.get("USER");
    if(username == "") { return Return_codes.NO_USERNAME_ENV_VARIABLE; }

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
        stderr.writef("Unable to open the sqlite database; Sqlite3 error code : %s\n", open_code);
        return Return_codes.UNABLE_TO_CREATE_TAGGY_DB;
    }

    sqlite3_stmt* db_version;
    int select_code =
    select(
        database_connection,
        Table.config,
        [Configurations_field.setting, Configurations_field.value],
        [Configurations_field.setting ~ "='version'"],
        db_version
    );

    if( select_code ) {
        // TODO make the fucking tables cause if this don't work the db is emptyyyyyyyy
        stderr.writef("Unable to execute query: sqlite3_prepare_v2 code : %s\n", select_code);
        return Return_codes.QUERY_FAILED;
    }

    return Return_codes.OK;
}


int select(sqlite3* database, Table table, string[] fields, string[] filter, sqlite3_stmt* query_stmt) {
    string query_string =
    "SELECT "
    ~ fields.join(",")
    ~ " FROM "
    ~ table
    ~ " WHERE "
    ~ filter.join(",")
    ~ ";";
    const(char*) query = cast(const(char*)) query_string;

    int prepare_code = sqlite3_prepare_v2(
        database,
        query,
        cast(int)query_string.length+1,
        &query_stmt,
        null
    );

    return prepare_code;
}


enum Return_codes {
    OK,
    UNABLE_TO_CREATE_TAGGY_DIR,
    UNABLE_TO_CREATE_TAGGY_DB,
    TAGGY_DIR_NOT_A_DIR,
    NO_HOME_ENV_VARIABLE,
    NO_USERNAME_ENV_VARIABLE,
    QUERY_FAILED,
}

enum Table {
    tags = "tags",
    config = "configuration",
    elements = "elements",
    tags_elements = "tags_elements",
    taggroup = "taggroup",
    properties = "properties",
    properties_tags = "properties_tags",
    properties_elements = "properties_elements",
}

enum Tags_field {
    name = "name",
    description = "description",
}
enum Elements_field {
   hash_id = "hash_id" ,
   value = "value" ,
}
enum Tags_elements_field {
   tag_id = "tag_id" ,
   elements_id = "elements_id" ,
}
enum Taggroup_field {
   group_id = "group_id" ,
   tag_id = "tag_id" ,
}
enum Properties_field {
   property = "property" ,
}
enum Properties_tags_field {
   property_id = "property_id" ,
   tag_id = "tag_id" ,
   pervasive = "pervasive" ,
}
enum Properties_elements_field {
   property_id = "property_id" ,
   elements_id = "elements_id" ,
}
enum Configurations_field {
   setting = "setting" ,
   value = "value" ,
   description = "description" ,
}

 /*
 database schema
 tables:
     tags:
         -name:varchar[255]
         -description:string
     elements:
         -hash-id:int
         -value:string
     tags-elements:
         -tag-id:int
         -elements-id:int
     taggroup:
         -group-id:int    # indexes into the tags id
         -tag-id:int
     properties
         -property:enum
     properties-tags
         -property-id:int
         -tag-id:int
         -pervasive:bool    # if pervasive is true a tag witht the property can only get associated with an element that has that property; to be dicided if opposite should be true as well
     properties-elements:
         -property-id:int
         -elements-id:int
     configurations:
         -setting:varchar[64]
         -value:varchar[64]
         -description:string
*/
