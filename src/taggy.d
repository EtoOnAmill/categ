import std.stdio;
import std.conv;
import std.string;
import std.array;
import std.algorithm;
import std.file;
import etc.c.sqlite3;
import std.getopt;
import std.process;

const(string) DATABASE_VERSION = "0.0.1";

int main(string[] args) {
    arraySep = ",";

    bool daemon_mode = false;
    string[] tags;
    string action;
    getopt(args,
           std.getopt.config.passThrough,
           "daemon|d", &daemon_mode,
           "tags|t", &tags,
           "action|a", &action,
    );
    string[] elements = get_elements(args);


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
        database_name.toStringz,
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
        [Configuration_field.value],
        [Configuration_field.setting ~ "=\"version\""],
        &db_version
    );

    if( select_code ) {
        sqlite3_finalize(db_version);

        int create_code = create_table(database_connection, Table.config);
        if ( create_code ) {
            return Return_codes.QUERY_FAILED;
        }

        int insert_code = insert_values(
            database_connection,
            Table.config,
            [ Configuration_field.setting, Configuration_field.value ],
            [[ "version".quote, DATABASE_VERSION.quote ]]);
        if ( insert_code ) {
            return Return_codes.QUERY_FAILED;
        }
    }

    if(db_version == null) {assert(0, "wtf");}
    int db_vers_code = sqlite3_step(db_version);
    if ( db_vers_code != SQLITE_ROW ) {
        sqlite3_finalize(db_version);

        stderr.writef("Configuration table is corrupted, unable to get database version; sqlite3_step code : %s\n", db_vers_code);
        return Return_codes.DATABASE_ERROR;
    }

    const(char)* current_version = sqlite3_column_text(db_version, 0);
    if( current_version.fromStringz != DATABASE_VERSION.fromStringz ) {
        stderr.writef("Incompatible database versions %s %s\n TODO make documentation for migration",current_version, DATABASE_VERSION);
        return Return_codes.DATABASE_ERROR;
    }
    sqlite3_finalize(db_version);


/*
actions:
    Add    # if only tag or elements defined add each to relative database, if both present also add a connection for every tag to every element mentioned, default action when not defined
    Delete # remove the elements or tags or remove the connection of tag and element if both are defined
    Group  # similar to add but both tags and elements must be defined, the elements are tags as well
*/
    char action_short = 'a';
    if(action.length != 0) { action_short = action[0]; }
    switch (action_short) {
        case 'D': case 'd':
            assert(0, "TODO");
            break;

        case 'G': case 'g':
            assert(0, "TODO");
            break;

        case 'A': case 'a':
            int insert_code;
            if(tags.length > 0) {
                insert_code =
                insert_values(
                    database_connection,
                    Table.tags,
                    [Tag_field.name],
                    tags.map!( e => [ e.quote ] ).array);
                if( insert_code ) {
                    stderr.writef("Unable to add tags to database\n");
                    return Return_codes.DATABASE_ERROR;
                }
            }
            if(elements.length > 0) {
                insert_code =
                insert_values(
                    database_connection,
                    Table.elements,
                    [Element_field.value, Element_field.hash_id],
                    elements.map!( e => [ e.quote, e.hashOf.text ] ).array);
                if( insert_code ) {
                    stderr.writef("Unable to add elements to database\n");
                    return Return_codes.DATABASE_ERROR;
                }
            }
            if(tags.length > 0 && elements.length > 0) {
                assert(0, "TODO");
            }
            break;

        default:
            string[] available_actions = ["Add","Delete","Group"];
            stderr.writef(
                "Wrong action parameter, expected either %s but found %s\n",
                available_actions,
                action
            );
            return Return_codes.WRONG_ARGUMENTS;
    }

    writeln("With Action \t\t", action);
    writeln("With tags \t\t", tags);
    writeln("To elements \t\t", elements);
    
    return Return_codes.OK;
}

string[] get_elements(string[] leftover_args) {
    // TODO: if leftover args is empty get the elements from stdin
    return leftover_args[1..$];
}

string quote(string to) {
    return '"' ~ to ~ '"';
}

int insert_values(sqlite3* database, Table table, string[] fields, string[][] values) {
    string query_string =
    "INSERT INTO "
    ~ table
    ~ " ( "
    ~ fields.join(",")
    ~ " ) VALUES "
    ~ values.map!( vals => "(" ~ vals.join(",") ~ ")" ).join(",");

    writeln(query_string);

    int code =sqlite3_exec(database, query_string.toStringz, null, null, null);

    switch(code) {
        case 0: break;
        case 19:
            stderr.writef(
                "Insertion failed because of constraint, possibly one or more tags already exist");
            break;
        default:
            stderr.writef(
                "Insertion into %s table failed; sqlite3_exec code %s\n",
                table,
                code
            );
        break;
    }

    return code;
}

int create_table(sqlite3* database, Table table) {
    string[] fields = [];

    final switch( table ) {
        case Table.tags :
            fields ~= Tag_field.name ~ " TEXT";
            fields ~= Tag_field.description ~ " TEXT";
            fields ~= Tag_field.hash_id ~ " INTEGER PRIMARY KEY"; // hash of both name and description
            break;
        case Table.elements :
            fields ~= Element_field.value ~ " TEXT";
            fields ~= Element_field.description ~ " TEXT";
            fields ~= Element_field.hash_id ~ " INTEGER PRIMARY KEY";
            break;
        case Table.tags_elements :
            fields ~= text(
                Tag_element_field.tag_id, " INTEGER ",
                " REFERENCES ", Table.tags, "(", Tag_field.hash_id,") ON DELETE NO ACTION" );
            fields ~= text(
                Tag_element_field.elements_id, " INTEGER ",
                " REFERENCES ", Table.elements, "( hash_id ) ON DELETE NO ACTION ON UPDATE CASCADE" );
            break;
        case Table.taggroup :
            fields ~= Taggroup_field.group_id ~ " INTEGER";
            fields ~= Taggroup_field.tag_id ~ " INTEGER";
            break;
        case Table.properties :
            fields ~= Property_field.property ~ " TEXT";
            break;
        case Table.properties_tags :
           fields ~= Property_tag_field.property_id ~ " INTEGER";
            fields ~= Property_tag_field.tag_id ~ " INTEGER";
            fields ~= Property_tag_field.pervasive ~ " INTEGER";
            break;
        case Table.properties_elements :
            fields ~= Property_element_field.property_id ~ " INTEGER";
            fields ~= Property_element_field.elements_id ~ " INTEGER";
            break;
        case Table.config :
            fields ~= Configuration_field.setting ~ " TEXT UNIQUE ON CONFLICT FAIL";
            fields ~= Configuration_field.value ~ " TEXT";
            fields ~= Configuration_field.description ~ " TEXT";
            break;
    }

    string query_string =
    "CREATE TABLE IF NOT EXISTS "
    ~ table
    ~ " ( "
    ~ fields.join(" , ")
    ~ " )";

    writeln(query_string);
    int create_code =
    sqlite3_exec(
        database,
        query_string.toStringz,
        null, // callback function
        null, // first arg to callback function
        null // error message string pointer
    );

    if( create_code ) {
        stderr.writef(
            "Creation of %s table failed; sqlite3_exec code : %s\n",
            table,
            create_code
        );
    }

    return create_code;
}

int select(sqlite3* database, Table table, string[] fields, string[] filter, sqlite3_stmt** sqlite_stmt) {
    string query_string =
    "SELECT "
    ~ fields.join(",")
    ~ " FROM "
    ~ table
    ~ " WHERE "
    ~ filter.join(",");

    writeln(query_string);
    int prepare_code = sqlite3_prepare_v2(
        database,
        query_string.toStringz,
        -1,
        sqlite_stmt,
        null
    );

    if( prepare_code ) {
        stderr.writef(
            "Selection into %s failed; sqlite3_prepare_v2 code : %s\n",
            table,
            prepare_code
        );
    }

    return prepare_code;
}


enum Table {
    tags = "tags",
    config = "configurations",
    elements = "elements",
    tags_elements = "tags_elements",
    taggroup = "taggroup",
    properties = "properties",
    properties_tags = "properties_tags",
    properties_elements = "properties_elements",
}

enum Tag_field {
    name = "name",
    description = "description",
    hash_id = "hash_id",
}
enum Element_field {
   value = "value" ,
   description = "description",
   hash_id = "hash_id" ,
}
enum Tag_element_field {
   tag_id = "tag_id" ,
   elements_id = "elements_id" ,
}
enum Taggroup_field {
   group_id = "group_id" ,
   tag_id = "tag_id" ,
}
enum Property_field {
   property = "property" ,
}
enum Property_tag_field {
   property_id = "property_id" ,
   tag_id = "tag_id" ,
   pervasive = "pervasive" ,
}
enum Property_element_field {
   property_id = "property_id" ,
   elements_id = "elements_id" ,
}
enum Configuration_field {
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
         -group-id:int
         -tag-id:int
     properties
         -property:enum
     properties-tags
         -property-id:int
         -tag-id:int
         -pervasive:bool
     properties-elements:
         -property-id:int
         -elements-id:int
     configurations:
         -setting:varchar[64]
         -value:varchar[64]
         -description:string
*/

enum Return_codes {
    OK,
    DATABASE_ERROR,
    UNABLE_TO_CREATE_TAGGY_DIR,
    UNABLE_TO_CREATE_TAGGY_DB,
    TAGGY_DIR_NOT_A_DIR,
    NO_HOME_ENV_VARIABLE,
    NO_USERNAME_ENV_VARIABLE,
    QUERY_FAILED,
    QUERY_CREATION_FAILED,
    WRONG_ARGUMENTS,
}
