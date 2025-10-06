#ifndef guile_db_h_INCLUDED
#define guile_db_h_INCLUDED

extern sqlite3* database;

int all_tables_exist(void);
void make_scm_bindings(void*);
void make_scm_module(void);

#endif // guile_db_h_INCLUDED
