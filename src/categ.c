#include <libguile.h>
#include <sqlite3.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "guile_db.h"


// Return codes
enum RETURN_CODES {
    OK,
    MISSING_ENVAR,
    DATABASE_ERROR,
    SCHEME_ERROR,
};


struct InnerArgs {
    int argc;
    char** argv;
    char* categ_dir;
    char* db_file;
};

// globals
char* categ_dir;
char* db_file;
char* home_dir;
char* user;
char* categ_dir;
char* xdg_data_home;
char* db_name;
// sqlite3* database in guile_db.h

// string utils
char* concat(char* str1, char* str2) {
    int len1 = strlen(str1);
    int len2 = strlen(str2);
    int tot_len = len1 + len2 + 1; // null char

    char* ret = calloc(tot_len, 1);

    memmove(ret, str1, len1);
    memmove(ret+len1, str2, len2);

    return ret;
}
void append(char** dst, char* src) {
    int dst_len = strlen(*dst);
    int src_len = strlen(src);
    int tot_len = dst_len + src_len + 1; // null char

    *dst = realloc(*dst, tot_len);

    memmove(*(dst)+dst_len, src, src_len);

    (*dst)[tot_len-1] = 0; // -1 because arrays are indexed at zero

    return;
}
// end string utils


// ENVAR
char* tmp;
char* get_env(char* variable, char* deflt) {
    char* ret = malloc(0);

    if( (tmp = getenv(variable)) != NULL ) {
        int len = strlen(tmp);
        //printf("%s variable length = %d\n", tmp, len);

        append(&ret, tmp);
        tmp = NULL;

        ret[len] = '\0'; // null terminator :3
        return ret;
    } else {
        if( deflt != NULL ) {
            fprintf(stderr, "%s enviroment variable not set, using default %s\n", variable, deflt);
            return deflt;
        } else {
            fprintf(stderr, "%s enviroment variable not set, unable to continue\n", variable);
            exit(MISSING_ENVAR);
        }
    }
}
// end ENVAR





void* inner_main(struct InnerArgs* inner_args) {

    make_scm_module();

    char* load_categ; 
    load_categ = concat("(add-to-load-path \"", categ_dir);
    append(&load_categ, "\")");

    scm_c_eval_string(load_categ);
    scm_c_use_module("guiledb");
    scm_c_use_module("categ");
    scm_c_use_module("db-interface");


    SCM arg_list = scm_list_n(SCM_UNDEFINED);
    for(int i = inner_args->argc - 1; i>0; i--) {
        arg_list = scm_cons(
            scm_from_locale_string(inner_args->argv[i]),
            arg_list);
    }


    SCM entry = scm_c_public_ref("categ", "entry");

    scm_call_1(entry, arg_list);
    //scm_shell(inner_args->argc, inner_args->argv);

    return NULL;
}




int main(int argc, char** argv) {

    home_dir = get_env("HOME", NULL);
    user = get_env("USER", "categ");
    xdg_data_home = get_env("XDG_DATA_HOME", concat(home_dir, "/.local/share"));
    categ_dir = get_env("CATEG_DIR", concat(xdg_data_home, "/categ"));

    if( categ_dir[0] == '\0' || categ_dir == NULL) {
        append(&categ_dir, home_dir);
        append(&categ_dir, ".local/share/categ/");
    }

    db_name = concat(categ_dir, "/");
    append(&db_name, user);
    append(&db_name, ".db");

    printf("Home dir: %s\n", home_dir);
    printf("User: %s\n", user);
    printf("Categ dir: %s\n", categ_dir);
    printf("Db name: %s\n", db_name);


    int connection_res = sqlite3_open_v2(
        db_name,
        &database,
        SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
        NULL
    );

    if(connection_res) { 
        fprintf(stderr, "Unable to open database %s ; error:%d",db_name, connection_res); 
        exit(DATABASE_ERROR);
    }

    struct InnerArgs inner_args = {
        .argc = argc,
        .argv = argv,
    };
    scm_with_guile((void* (*)(void*)) &inner_main, &inner_args);

    int close = sqlite3_close_v2(database);
    if( close ) {
        fprintf(stderr, "Unable to close database %s ; error:%d",db_name, connection_res); 
        exit(DATABASE_ERROR);
    }

    return OK;
}
