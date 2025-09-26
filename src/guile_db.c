#include <string.h>
#include <libguile.h>
#include <sqlite3.h>
#include <stdlib.h>

#define DEFAULT_SIZE 50


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


SCM guiledb_add(SCM database, SCM row, SCM value) {
    if( scm_vector_p(row) == SCM_BOOL_T && scm_vector_p(value) == SCM_BOOL_T ) {
        if( scm_c_vector_length(row) != scm_c_vector_length(value) ) {
            return SCM_BOOL_F;
        }
    } else {
        return SCM_BOOL_F;
    }

    char* db_name = scm_to_locale_string(database);

    char* col_names = calloc(DEFAULT_SIZE,1);
    append(&col_names, "(");
    append(&col_names, vec_to_seq(row));
    append(&col_names, ")");

    char* values = calloc(DEFAULT_SIZE,1);
    append(&values, "(");
    append(&values, vec_to_seq(value));
    append(&values, ")");

    char* query = calloc(DEFAULT_SIZE,1);
    append(&query, "INSERT INTO ");
    append(&query, db_name);
    append(&query, col_names);
    append(&query, " VALUES ");
    append(&query, values);

    return scm_from_locale_string(query);
}

void init_module() {
    scm_c_define_gsubr("guiledb-add", 3, 0, 0, guiledb_add);
}
