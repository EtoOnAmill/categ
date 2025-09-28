(define-module (taggy)
    #:export (hi table-add table-remove table-select))

(load-extension "./build/guile_db.so" "init_module")

(define hi (lambda () (display "BYE\n")))



(define* (table-select table rows #:key join . filters)
    (let*
         ((join-str (if join join " AND "))
          (filter-no-key
              (if join
                   (delv join (delv #:join filters))
                   filters))
          (filter-str
              (cond
              ((nil? filter-no-key) "TRUE")
              ((pair? filter-no-key) (apply string-append (intersperse join-str filter-no-key))))))
    (select_query table rows filter-str)))

(define (select_query table rows filter)
    (if (and 
            (string? table) 
            (vector? rows)
            (string? filter))
        (let
            ((query (string-append "SELECT " (symvec->str rows) " FROM " table " WHERE " filter "\n")))
            (begin (display query) (guiledb-select query)))
        #f ))

(define (table-add table rows . values)
    (cond
        ((nil? values) #t)
        ((pair? values)
            (if (add_query table rows (list->vector (car values)))
                (apply table-add table rows (cdr values)) ; without apply with every recursion the 'values' variadic argument gets wrapped in an extra list instead of using the list itself
                values))
        (#t (list table rows values))))

(define (add_query table rows values)
    (if (and
            (string? table)
            (vector? rows)
            (vector? values)
            (eq? (vector-length values) (vector-length rows)))
        (let 
            ((query (string-append "INSERT INTO " table "("(symvec->str rows) ") VALUES " (strvec->str values) "\n")))
            (begin
                (display query)
                (guiledb-query query)))
        #f ))



(define (table-remove table . selectors)
    (cond
        ((nil? selectors) #t)
        ((pair? selectors)
            (if (remove_query table (car selectors))
                (apply table-remove (cons table (cdr selectors)))
                selectors))
        (#t (list table selectors))))

(define (remove_query table selector)
    (if (and (string? table) (string? selector))
        (let 
            ((query (string-append "DELETE FROM " table " WHERE " selector "\n")))
            (begin
                (display query)
                (guiledb-query query)))
        #f ))




(define (symvec->str v)
    (if (eq? 0 (vector-length v))
        "*"
        (string-append (string-join (map symbol->string (vector->list v)) ",") )))
(define (strvec->str v)
    (string-append "(" (string-join (vector->list v) ",") ")" ))
(define (intersperse operator operands)
;    (display operator)
;    (display operands)
;    (display "\n______\n")
    (cond
        ((nil? operands) operands)
        ((nil? (cdr operands)) operands)
        ((pair? operands)
            (cons (car operands) (cons operator (intersperse operator (cdr operands)))))))
