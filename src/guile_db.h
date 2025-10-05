#ifndef guile_db_h_INCLUDED
#define guile_db_h_INCLUDED

extern sqlite3* database;

SCM guiledb_query(SCM);
SCM guiledb_select(SCM);
void make_scm_bindings(void*);
void make_scm_module(void);

#endif // guile_db_h_INCLUDED
