#include <string.h>
#include <libguile.h>
#include <sqlite3.h>
#include <stdlib.h>
#include <stdio.h>

#define DEFAULT_SIZE 50
#define DATABASE_NAME "/home/etonit/.local/taggy/etonit.db" // TODO fetch it dynamically like in taggy.d

sqlite3* database;
int connection_res;


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


char* vec_to_seq(SCM vector) {
    size_t len = scm_c_vector_length(vector);

    char* ret = calloc(DEFAULT_SIZE,1);

    for(size_t i=0; i<len; i++) {
        SCM item = scm_c_vector_ref(vector, i);
        if( !scm_is_symbol(item) ) return NULL;
        SCM scm_str = scm_symbol_to_string(item);
        char* item_s = scm_to_locale_string(scm_str);

        if( i ) append(&ret, ",");
        append(&ret, item_s);

        free(item_s);
    }

    return ret;
}

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
    SCM accumulator = scm_list_n(SCM_BOOL_T, SCM_UNDEFINED); // the bool is to have something to cdr on the first iteration of the callback

    int res = sqlite3_exec(
        database, 
        scm_to_locale_string(query_str), 
        (int (*)(void*,int,char**,char**)) &select_callback, 
        &accumulator, 
        NULL);

    if (res) {
        return scm_from_int(res);
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

SCM connection_result() {
    return scm_from_int(connection_res);
}

void init_module() {
    connection_res = sqlite3_open_v2(
        DATABASE_NAME,
        &database,
        SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
        NULL
    );

    if(connection_res) { fprintf(stderr, "Unable to open database %l", connection_res); }
    scm_c_define_gsubr("guiledb-status", 0, 0, 0, connection_result);
    scm_c_define_gsubr("guiledb-query", 1, 0, 0, guiledb_query);
    scm_c_define_gsubr("guiledb-select", 1, 0, 0, guiledb_select);
}
