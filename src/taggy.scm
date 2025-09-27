(define-module (taggy)
    #:export (hi db_add add_query))

(load-extension "./build/guile_db.so" "init_module")

(define hi (lambda () (write "BYE\n")))


(define (table_add table rows . values)
    (cond
        ((nil? values) #t)
        ((nil? (car values)) #t)
        ((pair? values)
            (if (add_query table rows (list->vector (car values)))
                (apply table_add table rows (cdr values)) ; without apply with every recursion the 'values' variadic argument gets wrapped in an extra list instead of using the list itself
                values))
        (#t (list table rows values))))
(define (add_query table rows values)
    (if (and
            (string? table)
            (vector? rows)
            (vector? values)
            (eq? (vector-length values) (vector-length rows)))
        (begin
            (display (string-append "INSERT INTO " table (symvec->str rows) " VALUES " (strvec->str values) "\n"))
           #t )
        #f ))


(define (table_remove table . selectors)
    (cond
        ((nil? selectors) #t)
        ((pair? selectors)
            (if (remove_query table (car selectors))
                (apply table_remove (cons table (cdr selectors)))
                selectors))
        (#t (list table selectors))))
(define (remove_query table selector)
    (if (and (string? table) (string? selector))
        (begin
            (display (string-append "DELETE FROM " table " WHERE " selector "\n"))
            #t )
        #f ))

(define (symvec->str v)
    (string-append "(" (string-join (map symbol->string (vector->list v)) ",") ")" ))
(define (strvec->str v)
    (string-append "(" (string-join (vector->list v) ",") ")" ))
