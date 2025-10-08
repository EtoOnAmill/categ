(define-module (db-interface)
    #:export (table-add table-remove table-select table-join)
    #:autoload (guiledb) (guiledb-query guiledb-select))

(define (join_subquery table1 table2 join-constraint)
    (if (and
         (string? table1)
         (string? table2)
         (string? join-constraint))
        (let (
            (query (string-append table1 " JOIN " table2 " ON " join-constraint))
        )
            (begin (display query) query))))


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
                  (cons (add-tag (car vals)) accumulator)))))
     (('link l-er l-ed)
      (let loop-er ((linkers l-er) (acc-er '()))
          (let loop-ed ((linked l-ed) (acc-ed '()))
              (cond
                  ((and (pair? linkers) (pair? linked))
                   (loop-ed
                      (cdr linked)
                      (cons (add-link (car linkers) (car linked)) acc-ed)))
                  ((and (pair? linkers) (nil? linked))
                      (loop-er (cdr linkers) (cons acc-ed acc-er)))

                  ((and (nil? linkers) (pair? linked))
                      acc-er)
                  ((and (nil? linkers) (nil? linked))
                      acc-er)

                  ((and (pair? linkers) (string? linked))
                   (process-query `(link ,linkers (,linked))))
                  ((and (string? linkers) (pair? linked))
                   (process-query `(link (,linkers) ,linked)))
                  ((and (string? linkers) (string? linked))
                   (process-query `(link (,linkers) (,linked))))))))
     (('get . filters)
      (display (get-linked filters)))))

(define (filters->selectors filters)
    (match (car filters)
         ('and
          (string-append "(" (h-filt->sel (cdr filters) "" " AND ") ")" ))
         ('or
          (string-append "(" (h-filt->sel (cdr filters) "" " OR ") ")" ))
         ('not
          (string-append "NOT (" (h-filt->sel (cdr filters) "" " OR ") ")" ))
         (else
          (string-append "(" (h-filt->sel filters "" " AND ") ")" ))))

(define* (h-filt->sel filters #:optional (acc "") (join " AND "))
    (let ((join-middle (if (eq? acc "") "" join)))
    (if (nil? filters) acc
    (if (string? (car filters))
        (h-filt->sel
         (cdr filters)
         (string-append acc join-middle "\"linker_id\"=" (s-string-hash (car filters)))
         join)
    (if (symbol? (car filters))
        (h-filt->sel
         (cdr filters)
         (string-append acc join-middle "\"linker_id\"=" (s-string-hash (symbol->string (car filters))))
         join)
    (if (keyword? (car filters))
        (h-filt->sel
         (cdr filters)
         (string-append acc join-middle "\"hash_id\"=" (s-string-hash (symbol->string (keyword->symbol (car filters)))))
         join)
    (if (list? (car filters))
     (h-filt->sel
      (cdr filters)
      (string-append acc join-middle (filters->selectors (car filters)))))))))))

(define (get-linked l-ers)
    (let ((join-subq
             (join_subquery
              "tags"
              "links"
              "tags.hash_id=links.linked_id")))
    (let loop ((linkers l-ers) (ret '()))
        (if (nil? linkers)
            ret
            (loop
             (cdr linkers)
             (cons 
              (cons 
                   (car linkers)
                   (cdr (table-select ; cdr because first value of select list is the column names which we don't care about
                       join-subq
                       #(tags.name)
                       (string-append "\"linker_id\"=" (s-string-hash (car linkers))))))
              ret))))))


(define (add-link linker linked)
    (table-add
     "links"
     #(linker_id linked_id)
     (list (s-string-hash linker) (s-string-hash linked))))
    
(define (add-tag val)
    (table-add
        "tags"
        #(name hash_id)
        (list val (s-string-hash val))))
    
(define (s-string-hash str) 
    str)
    ;(number->string (string-hash str)))
    
(define print-many (lambda a
    (if (not (nil? a))
        (begin
         (write (car a))
         (display "\n")
         (apply print-many (cdr a))))))
