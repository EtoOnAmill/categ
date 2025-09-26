(define-module (taggy)
    #:export (hi db_add add_query))

(load-extension "./build/guile_db.so" "init_module")

(define hi (lambda () (write "BYE\n")))

(define db_add (lambda (db rows . values)
    (cond
        ((nil? values) #t)
        ((nil? (car values)) #t)
        ((pair? values)
            (if (add_query db rows (list->vector (car values)))
                (apply db_add db rows (cdr values))
                values))
        (#t (list db rows values)))))

(define (symvec->str v)
    (string-append "(" (string-join (map symbol->string (vector->list v)) ",") ")" ))
(define (strvec->str v)
    (string-append "(" (string-join (vector->list v) ",") ")" ))

(define (add_query db rows values)
    (cond
        ((not (or
            (string? db)
            (vector? rows)
            (vector? values)
            (eq? (vector-length values) (vector-length rows)))) #f)
        (#t (begin
                   (write (string-append "INSERT INTO " db (symvec->str rows) " VALUES " (strvec->str values)))
                   #t))))
