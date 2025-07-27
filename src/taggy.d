import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.file;
import etc.c.sqlite3;
import std.getopt;
import std.process;

const(string) DATABASE_VERSION = "0.0.1";

/*
add
delete
tag
*/
int main(string[] args) {
    bool daemon_mode = false;
    string[] tags;
    string[] elements;
    getopt(args,
           "daemon", &daemon_mode,
           "t", &tags,
           "e", &elements,
    );

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

        stderr.writef("Unable to query database version : sqlite3_prepare_v2 code : %s\n", select_code);

        int create_code = create_table(database_connection, Table.config);
        if ( create_code ) {
            stderr.writef("Unable to create configuration table : sqlite3_exec code : %s\n", create_code);
            return Return_codes.QUERY_FAILED;
        }

        int insert_code = insert_values(
            database_connection,
            Table.config,
            [ Configuration_field.setting, Configuration_field.value ],
            [[ "version".quote, DATABASE_VERSION.quote ]]);
        if ( insert_code ) {
            stderr.writef("Unable to add version to database : sqlite3_exec code : %s\n", insert_code);
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
    writeln("Current database version is ", current_version.fromStringz);

    return Return_codes.OK;
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
    return sqlite3_exec(database, query_string.toStringz, null, null, null);
}

int create_table(sqlite3* database, Table table) {
    string[] fields = [];

    final switch( table ) {
        case Table.tags :
            fields ~= Tag_field.name ~ " TEXT UNIQUE";
            fields ~= Tag_field.description ~ " TEXT";
            break;
        case Table.elements :
            fields ~= Element_field.hash_id ~ " INTEGER UNIQUE";
            fields ~= Element_field.value ~ " TEXT";
            break;
        case Table.tags_elements :
            fields ~= Tag_element_field.tag_id ~ " INTEGER";
            fields ~= Tag_element_field.elements_id ~ " INTEGER";
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
            fields ~= Configuration_field.setting ~ " TEXT UNIQUE";
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
}
enum Element_field {
   hash_id = "hash_id" ,
   value = "value" ,
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
}
