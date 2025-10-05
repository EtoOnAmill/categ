(define-module (db-interface)
    #:export (table-add table-remove table-select)
    #:autoload (guiledb) (guiledb-query guiledb-select))

(define* (table-select table rows #:key join . filters)
    (let* (
         (join-str (if join join " AND "))
         (filter-no-key
             (if join
                  (delv join (delv #:join filters))
                  filters))
         (filter-str
             (cond
             ((nil? filter-no-key) "TRUE")
             ((pair? filter-no-key) (apply string-append (intersperse join-str filter-no-key)))))
    )
        (select_query table rows filter-str)))

(define (select_query table rows filter)
    (if (and 
            (string? table) 
            (vector? rows)
            (string? filter))
        (let (
            (query (string-append "SELECT " (symvec->str rows) " FROM " table " WHERE " filter "\n"))
        )
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
        (let (
            (query (string-append "INSERT INTO " table "("(symvec->str rows) ") VALUES " (strvec->str values) "\n"))
        )
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
        (let (
            (query (string-append "DELETE FROM " table " WHERE " selector "\n"))
        )
            (begin
                (display query)
                (guiledb-query query)))
        #f ))




(define (symvec->str v)
    (if (eq? 0 (vector-length v))
        "*"
        (string-append (string-join (map symbol->string (vector->list v)) ",") )))
(define (strvec->str v)
    (string-append "('" (string-join (vector->list v) "','") "')" ))
(define (intersperse operator operands)
;    (display operator)
;    (display operands)
;    (display "\n______\n")
    (cond
        ((nil? operands) operands)
        ((nil? (cdr operands)) operands)
        ((pair? operands)
            (cons (car operands) (cons operator (intersperse operator (cdr operands)))))))




(define-module (categ)
    #:export (entry)
    #:use-module (db-interface)
    #:use-module (ice-9 match))

(define (first-chr str)
    (if (string? str)
        (car (string->list str))
        #\0))

(define help-text
    "\nTODO\n\n")

(define (entry args) 
    (if (nil? args) 
     (display help-text)
     (handle-args (parse-args args '()))))

(define (parse-args args ret)
    (print-many "args :" args)
    (match args
        ('() ret)
        (("-h" . rest) (begin (display help-text) '()))
        ((hd . tl)
            (if (eq? #\( (first-chr hd))
                (parse-args tl (cons `("QUERY" ,hd) ret))
                (begin (display "Unrecognized argument") '())))))


(define (handle-args arg-pairs)
    ;(print-many "arg-pairs :" arg-pairs)
    (match arg-pairs
        ('() #t)
        ((("QUERY" query) . tl )
         (begin
             (process-query (with-input-from-string query read))
             (handle-args tl)))
        (else (print-many "Unable to recognize args" arg-pairs))))

(define (process-query query) 
    ;(print-many "query :" query)
    (match query
     (('add . args)
      (let loop ((vals args) (accumulator '()))
          (if (nil? vals)
              accumulator
              (loop
                  (cdr vals)
                  (cons (add-tag (car vals)) accumulator)))))))
    
(define (add-tag val)
    (table-add
        "tags"
        #(name hash_id)
        (list val (number->string (string-hash val)))))
    
(define print-many (lambda a
    (if (not (nil? a))
        (begin
         (write (car a))
         (display "\n")
         (apply print-many (cdr a))))))
