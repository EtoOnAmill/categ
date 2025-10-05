#include <string.h>
#include <libguile.h>
#include <sqlite3.h>
#include <stdlib.h>
#include <stdio.h>

#include "guile_db.h"

#define DEFAULT_SIZE 50

sqlite3* database;

// arg is the 4th arg to sqlite3_exec
// sqlite3_exec(db, query, callback, c_arg, err) -> callback(c_arg, -, -, -)
int select_callback(SCM* accumulator, int col_n, char** col_vals, char** col_names) {

    *accumulator = scm_cdr(*accumulator);

    SCM row = scm_list_n(SCM_UNDEFINED); //should make the empty list

    for(int res_idx = col_n-1; res_idx >= 0; res_idx--) {
        SCM col_str;
        if( col_vals[res_idx] != NULL) {
            col_str = scm_from_locale_string(col_vals[res_idx]);
        } else {
            col_str = scm_from_locale_string("<>");
        }

        row = scm_cons(col_str, row);
    }

    *accumulator = scm_cons(row, *accumulator);

    SCM c_names = scm_list_n(SCM_UNDEFINED); //should make the empty list

    for(int col_name_idx = col_n-1; col_name_idx >= 0; col_name_idx--) {
        SCM col_name;
        if( col_names[col_name_idx] != NULL) {
            col_name = scm_from_locale_string(col_names[col_name_idx]);
        } else {
            col_name = scm_from_locale_string("<>");
        }

        c_names = scm_cons(col_name, c_names);
    }

    *accumulator = scm_cons(c_names, *accumulator);

    return 0; // 0 = ok, >0 = error
}

SCM guiledb_select(SCM query_str) {
    SCM accumulator = scm_list_n(SCM_BOOL_F, SCM_UNDEFINED); // the bool is to have something to cdr on the first iteration of the callback

    int res = sqlite3_exec(
        database, 
        scm_to_locale_string(query_str), 
        (int (*)(void*,int,char**,char**)) &select_callback, 
        &accumulator, 
        NULL);

    if (res) {
        return scm_from_int(res);
    } else if ( scm_car(accumulator) == SCM_BOOL_F ) {
        return scm_list_n(SCM_UNDEFINED);
    } else {
        return accumulator;
    }
}

SCM guiledb_query(SCM query_str) {
    int res = sqlite3_exec(database, scm_to_locale_string(query_str), NULL, NULL, NULL);

    if (res) {
        return scm_from_int(res);
    } else {
        return SCM_BOOL_T;
    }
}



void make_scm_bindings(void* _) {
    scm_c_define_gsubr("guiledb-query", 1, 0, 0, guiledb_query);
    scm_c_define_gsubr("guiledb-select", 1, 0, 0, guiledb_select);

    scm_c_export("guiledb-query", NULL);
    scm_c_export("guiledb-select", NULL);
}

void make_scm_module(void) {
    scm_c_define_module("guiledb", make_scm_bindings, NULL);
}
