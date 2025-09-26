(define-module (taggy)
    #:export (hi))

(load-extension "guile-db" "init_module")

(define hi (write-string "BYE"))

(define db_add (lambda (db rows . values)) 
    )
