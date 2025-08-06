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
           "operation|o", &action,
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

    if( table_exists(database_connection, Table.configurations) ) {

        sqlite3_stmt* db_version;
        int select_code =
        select(
            database_connection,
            Table.configurations.to_table_expression,
            [Configuration_field.value],
            [Configuration_field.setting ~ "=\"version\""],
            &db_version
        );
        if( select_code ) { return Return_codes.QUERY_FAILED; }

        assert(db_version, "Database version query sould never be null and reach this point, FATAL ERROR\n");

        int db_vers_code = sqlite3_step(db_version);
        if ( db_vers_code != SQLITE_ROW ) {
            sqlite3_finalize(db_version);

            stderr.writef("Configuration table is corrupted, unable to get database version; sqlite3_step code : %s\n", db_vers_code);
            return Return_codes.DATABASE_ERROR;
        }

        const(char)* current_version = sqlite3_column_text(db_version, 0);
        if( current_version.fromStringz != DATABASE_VERSION.fromStringz ) {
            sqlite3_finalize(db_version);

            stderr.writef("Incompatible database versions %s %s\n TODO make documentation for migration",current_version, DATABASE_VERSION);
            return Return_codes.DATABASE_ERROR;
        }
        sqlite3_finalize(db_version);

    } else {

        int create_code = create_table(database_connection, Table.configurations);
        if ( create_code ) { return Return_codes.QUERY_FAILED; }
        int insert_code = insert_values(
            database_connection,
            Table.configurations,
            [ Configuration_field.setting, Configuration_field.value ],
            [[ "version".quote_value, DATABASE_VERSION.quote_value ]]);
        if ( insert_code ) { return Return_codes.QUERY_FAILED; }
    }
    assert( !init_table(database_connection, Table.tags) );
    assert( !init_table(database_connection, Table.elements) );
    assert( !init_table(database_connection, Table.tags_elements) );



    writeln("With Action \t\t", action);
    writeln("With tags \t\t", tags);
    writeln("To elements \t\t", elements);
/*
actions:
    Add    # if only tag or elements defined add each to relative database, if both present also add a connection for every tag to every element mentioned, default action when not defined
    Delete # remove the elements or tags or remove the connection of tag and element if both are defined
    Group  # similar to add but both tags and elements must be defined, the elements are tags as well
    List   # list elements with their associated tags or tags with their associated elements, if both are present idk
*/
    switch (action) {
        case "Delete": case "D": case "d":
            if(tags.length > 0 && elements.length > 0) {
                string[] where;
                foreach(t; tags) {
                    foreach(e; elements) {
                        where ~= text("(", Tag_element_field.tag_id, "=", t.hashOf,
                        " AND ", Tag_element_field.element_id, "=", e.hashOf, ")");
                    }
                }

                string string_query = text (
                    "DELETE FROM ", Table.tags_elements,
                    " WHERE ", where.join(" OR ")
                );
                writeln(string_query);

                assert( !sqlite3_exec(
                    database_connection,
                    string_query.toStringz,
                    null,
                    null,
                    null,
                ), "Unable to remove tag link");
                break;
            }
            assert(0, "TODO");

        case "Group": case "G": case "g":
            assert(0, "TODO");
            break;

        case "List": case "L": case "l":
            if(tags.length > 0) {
                TableExpression tag_join = table_join(
                    Table.tags_elements.to_table_expression,
                    Table.tags.to_table_expression,
                    text(Tag_element_field.tag_id.full_name, "=", Tag_field.hash_id.full_name));
                TableExpression element_tag_join = table_join(
                    tag_join.quote_t_e("("),
                    Table.elements.to_table_expression,
                    text(Tag_element_field.element_id.full_name, "=", Element_field.hash_id.full_name));

                sqlite3_stmt* stmt;
                int code = select(
                    database_connection,
                    element_tag_join.quote_t_e("("),
                    [Tag_field.name.full_name, Element_field.value.full_name],
                    tags.map!(t => text(Tag_field.hash_id.full_name, "=", t.hashOf)).array,
                    &stmt);

                if( code ) {
                    stderr.writef("Unable to create query for tag connections; sqlite3_prepare code : %s\n", code);
                    return Return_codes.DATABASE_ERROR;
                }
                string[] tag;
                string[] element;

                while( sqlite3_step(stmt) == SQLITE_ROW ) {
                    tag ~= sqlite3_column_text(stmt, 0).text;
                    element ~= sqlite3_column_text(stmt, 1).text;
                }

                sqlite3_finalize(stmt);

                for(int i = 0; i < tag.length; i++) {
                    writeln(tag[i], " -> ", element[i]);
                }
                break;
            }

            if(tags.length == 0 && elements.length == 0) {
                sqlite3_stmt* stmt;
                int code = select(
                    database_connection,
                    Table.tags.to_table_expression,
                    [Tag_field.name, Tag_field.description],
                    ["true"],
                    &stmt );
                if( code ) {
                    stderr.writef("Unable to create query for tags; sqlite3_prepare code : %s\n", code);
                    return Return_codes.DATABASE_ERROR;
                }

                string[] tag;
                string[] desc;
                while( sqlite3_step(stmt) == SQLITE_ROW ) {
                    tag ~= sqlite3_column_text(stmt, 0).text;
                    desc ~= sqlite3_column_text(stmt, 1).text;
                }

                for(int i = 0; i < tag.length; i++) {
                    writeln(tag[i], " \"", desc[i], "\""); 
                }
                break;
            }
            break;

        case "Add": case "A": case "a":
            writeln("ADDING with tags ", tags, " and elements ", elements);
            int insert_code;
            if(tags.length > 0) {
                insert_code =
                insert_values(
                    database_connection,
                    Table.tags,
                    [Tag_field.name, Tag_field.hash_id],
                    tags.map!( e => [ e.quote_value, e.hashOf.text ] ).array);
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
                    elements.map!( e => [ e.quote_value, e.hashOf.text ] ).array);
                if( insert_code ) {
                    stderr.writef("Unable to add elements to database\n");
                    return Return_codes.DATABASE_ERROR;
                }
            }
            if(tags.length > 0 && elements.length > 0) {
                foreach(element; elements) {
                    insert_code =
                    insert_values(
                        database_connection,
                        Table.tags_elements,
                        [Tag_element_field.tag_id, Tag_element_field.element_id],
                        tags.map!( e => [e.hashOf.text, element.hashOf.text] ).array,
                    );
                    if( insert_code ) {
                        stderr.writef("Unable to tag %s element to tags %s\n", element, tags);
                        return Return_codes.DATABASE_ERROR;
                    }
                }
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
    
    return Return_codes.OK;
}

TableExpression table_join(TableExpression table_left, TableExpression table_right, string constraint) {
    return cast(TableExpression)text(
        table_left, " JOIN ", table_right,
        " ON ", constraint
    );
}

int init_table(sqlite3* database, Table table) {
    if( table_exists(database, table) ) {
        return create_table(database, table);
    }
    return SQLITE_OK;
}

string[] get_elements(string[] leftover_args) {
    // TODO: if leftover args is empty get the elements from stdin
    return leftover_args[1..$];
}

string quote(string inner, string around) {
    switch(around) {
        case "(": return text( "(",inner,")");
        default:
            return text(around,inner,around);
    }
}
string quote_value(string inner) {
    return inner.quote("'");
}

int insert_values(sqlite3* database, Table table, string[] fields, string[][] values) {
    string query_string = text(
    "INSERT INTO ",
    table,
    " ( ",
    fields.join(","),
    " ) VALUES ",
    values.map!( vals => "(" ~ vals.join(",") ~ ")" ).join(","));

    writeln(query_string);

    int code =sqlite3_exec(database, query_string.toStringz, null, null, null);

    switch(code) {
        case 0: break;
        case 19:
            stderr.writef(
                "Insertion into %s table failed because of constraints\n", table);
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

bool table_exists(sqlite3* database, Table table) {
    string query_string = text(
        "SELECT count(*) FROM sqlite_master ",
        "WHERE type='datbase' ",
        "AND name='", table,"'");

    sqlite3_stmt* stmt;
    int prepare_code = sqlite3_prepare_v2(
        database,
        query_string.toStringz,
        -1,
        &stmt,
        null);
    assert(!prepare_code, "Failed to prepare query for checking database existance\n");

    assert( sqlite3_step(stmt) == SQLITE_ROW, "Table existance query failed to execute" );

    int res = sqlite3_column_int(stmt, 0);

    sqlite3_finalize(stmt);

    return !cast(bool) res;
}

int create_table(sqlite3* database, Table table) {
    string[] fields = [];
    string constraints;

    final switch( table ) {
        case Table.tags :
            fields ~= Tag_field.name ~ " TEXT";
            fields ~= Tag_field.description ~ " TEXT";
            fields ~= Tag_field.hash_id ~ " INTEGER PRIMARY KEY ON CONFLICT IGNORE"; // hash of both name and description
            break;
        case Table.elements :
            fields ~= Element_field.value ~ " TEXT";
            fields ~= Element_field.description ~ " TEXT";
            fields ~= Element_field.hash_id ~ " INTEGER PRIMARY KEY ON CONFLICT IGNORE";
            break;
        case Table.tags_elements :
            fields ~= text(
                Tag_element_field.tag_id, " INTEGER ",
                " REFERENCES ", Table.tags, "(", Tag_field.hash_id,") ON DELETE NO ACTION ON UPDATE CASCADE" );
            fields ~= text(
                Tag_element_field.element_id, " INTEGER ",
                " REFERENCES ", Table.elements, "(", Element_field.hash_id,") ON DELETE NO ACTION ON UPDATE CASCADE" );
            constraints = text(
                "UNIQUE(", Tag_element_field.tag_id, ",", Tag_element_field.element_id,")",
                " ON CONFLICT IGNORE" );
            break;
        case Table.taggroups :
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
            fields ~= Property_element_field.element_id ~ " INTEGER";
            break;
        case Table.configurations :
            fields ~= Configuration_field.setting ~ " TEXT UNIQUE ON CONFLICT FAIL";
            fields ~= Configuration_field.value ~ " TEXT";
            fields ~= Configuration_field.description ~ " TEXT";
            break;
    }

    string[] definitions;
    if( constraints ) {
        definitions = (fields ~ constraints);
    } else {
        definitions = fields;
    }
    string query_string = text(
    "CREATE TABLE IF NOT EXISTS ", table,
    " ( ", definitions.join(" , "), " )");

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

int select(sqlite3* database, TableExpression table, string[] fields, string[] filter, sqlite3_stmt** sqlite_stmt) {
    string query_string = text(
    "SELECT ",
    fields.join(","),
    " FROM ",
    table,
    " WHERE ",
    filter.join(" OR "));

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


struct TableExpression {
    string val;
    string toString() {
        return this.val;
    }
    TableExpression quote_t_e(string outer) {
        return TableExpression(quote(this.val,outer));
    }
}
TableExpression to_table_expression(string t) {
    return TableExpression(t);
}

enum Table {
    tags = "tags",
    configurations = "configurations",
    elements = "elements",
    tags_elements = "tags_elements",
    taggroups = "taggroups",
    properties = "properties",
    properties_tags = "properties_tags",
    properties_elements = "properties_elements",
}


mixin(Field!(Table.tags, "Tag_field",
    "name", "description", "hash_id"));

mixin(Field!(Table.elements, "Element_field",
    "value", "description", "hash_id"));

mixin(Field!(Table.tags_elements, "Tag_element_field",
    "tag_id", "element_id" ));

mixin(Field!(Table.taggroups, "Taggroup_field",
    "group_id", "tag_id" ));

mixin(Field!(Table.properties, "Property_field",
    "property" ));

mixin(Field!(Table.properties_tags, "Property_tag_field",
    "property_id", "tag_id", "pervasive" ));

mixin(Field!(Table.properties_elements, "Property_element_field",
    "property_id", "element_id" ));

mixin(Field!(Table.configurations, "Configuration_field",
    "setting", "value", "description" ));

template Field(Table table, string field_enum_name, fields...) {
    const char[] Field = text(
        "enum ", field_enum_name, "{",
        [fields].map!(e => text(e,"=",e.quote("\""))).join(","),
        "}\n",
        "string full_name(", field_enum_name, " f) { return text(Table.", table, ", \".\", f); }" );
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
