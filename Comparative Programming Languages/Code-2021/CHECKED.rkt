#lang racket
(require eopl)
(provide (all-defined-out))

;;; Syntax
(define-datatype type type?
  (int-type)
  (bool-type)
  (proc-type (arg-type type?) (result-type type?))
  )

(define-datatype program program?
  (a-program (exp1 expression?)))

(define-datatype expression expression?
  (const-exp (num number?))
  (diff-exp (exp1 expression?) (exp2 expression?))
  (zero?-exp (exp1 expression?))
  (if-exp
   (exp1 expression?)
   (exp2 expression?)
   (exp3 expression?))
  (var-exp (var symbol?))
  (let-exp
   (var symbol?)
   (exp1 expression?)
   (body expression?))
  (proc-exp
   (var symbol?)
   (ty type?)
   (body expression?))
  (call-exp
   (rator expression?)
   (rand expression?))
  (letrec-exp
   (p-result type?)
   (p-name symbol?)
   (b-var symbol?)
   (b-var-type type?)
   (p-body expression?)
   (letrec-body expression?))
  )

(define (type->string ty)
  (cases type ty
    (int-type () "int")
    (bool-type () "bool")
    (proc-type (arg-type result-type ) (string-append "(" (type->string arg-type) " -> " (type->string result-type) ")"))
    ))

;; Semantics
(define-datatype expval expval?
  (num-val
   (value number?))
  (bool-val
   (boolean boolean?))
  (proc-val
   (proc proc?))
  )

;; proc? : SchemeVal -> Bool
;; procedure : Var * Exp * Env -> Proc
(define-datatype proc proc?
  (procedure
   (var symbol?)
   (body expression?)
   (env environment?))
  )

;; expval->num : ExpVal -> Int
(define expval->num
  (lambda (v)
    (cases expval v
      (num-val (num) num)
      (else (expval-extractor-error 'num v)))))

;; expval->bool : ExpVal -> Bool
(define expval->bool
  (lambda (v)
    (cases expval v
      (bool-val (bool) bool)
      (else (expval-extractor-error 'bool v)))))

;; expval->proc : ExpVal -> Proc
(define expval->proc
  (lambda (v)
    (cases expval v
      (proc-val (p) p)
      (else (expval-extractor-error 'proc v)))))

(define expval-extractor-error
  (lambda (variant value)
    (eopl:error 'expval-extractors "Looking for a ~s, found ~s"
                variant value)))

;; Environments
(define-datatype environment environment?
  (empty-env)
  (extend-env 
   (bvar symbol?)
   (bval expval?)
   (saved-env environment?))
  (extend-env-rec
   (id symbol?)
   (bvar symbol?)
   (body expression?)
   (saved-env environment?)))

(define apply-env
  (lambda (env search-sym)
    (cases environment env
      (empty-env ()
                 (eopl:error 'apply-env "No binding for ~s" search-sym))
      (extend-env (bvar bval saved-env)
                  (if (eqv? search-sym bvar)
                      bval
                      (apply-env saved-env search-sym)))
      (extend-env-rec (p-name b-var p-body saved-env)
                      (if (eqv? search-sym p-name)
                          (proc-val (procedure b-var p-body env))          
                          (apply-env saved-env search-sym))))))

;; init-env : () -> Env
(define init-env 
  (lambda ()
    (extend-env 
     'i (num-val 1)
     (extend-env
      'v (num-val 5)
      (extend-env
       'x (num-val 10)
       (empty-env))))))

;; Interpreter for LETREC

;; value-of-program : Program -> ExpVal
(define value-of-program 
  (lambda (pgm)
    (cases program pgm
      (a-program (exp1)
                 (value-of exp1 (init-env))))))

;; value-of : Exp * Env -> ExpVal
(define value-of
  (lambda (exp env)
    (cases expression exp
      (const-exp (num) (num-val num))
      (var-exp (var) (apply-env env var))
      (diff-exp (exp1 exp2)
                (let ((val1 (value-of exp1 env))
                      (val2 (value-of exp2 env)))
                  (let ((num1 (expval->num val1))
                        (num2 (expval->num val2)))
                    (num-val
                     (- num1 num2)))))
      (zero?-exp (exp1)
                 (let ((val1 (value-of exp1 env)))
                   (let ((num1 (expval->num val1)))
                     (if (zero? num1)
                         (bool-val #t)
                         (bool-val #f)))))
      (if-exp (exp1 exp2 exp3)
              (let ((val1 (value-of exp1 env)))
                (if (expval->bool val1)
                    (value-of exp2 env)
                    (value-of exp3 env))))
      (let-exp (var exp1 body)       
               (let ((val1 (value-of exp1 env)))
                 (value-of body
                           (extend-env var val1 env))))
      (proc-exp (var ty body)
                (proc-val (procedure var body env)))
      (call-exp (rator rand)
                (let ((proc (expval->proc (value-of rator env)))
                      (arg (value-of rand env)))
                  (apply-procedure proc arg)))
      (letrec-exp (ty1 p-name b-var ty2 p-body letrec-body)
          (value-of letrec-body
            (extend-env-rec p-name b-var p-body env)))
      )))

;; apply-procedure : Proc * ExpVal -> ExpVal
(define apply-procedure
  (lambda (proc1 val)
    (cases proc proc1
      (procedure (var body saved-env)
                 (value-of body (extend-env var val saved-env))))))

;;; Type checker --------------------------------------------------

;; check-equal-type! : Type * Type * Exp -> Unspecified
;; Page: 242
(define check-equal-type!
  (lambda (ty1 ty2 exp)
    (cond ((not (equal? ty1 ty2))
        (report-unequal-types ty1 ty2 exp)))))

;; report-unequal-types : Type * Type * Exp -> Unspecified
;; Page: 243
(define report-unequal-types
  (lambda (ty1 ty2 exp)
    (eopl:error 'check-equal-type!  
                "Types didn't match: ~s != ~a in~%~a"
                (type->string ty1)
                (type->string ty2)
                exp)))

;;;;;;;;;;;;;;;; type environments ;;;;;;;;;;;;;;;;

(define-datatype type-environment type-environment?
  (empty-tenv-record)
  (extended-tenv-record
   (sym symbol?)
   (type type?)
   (tenv type-environment?)))

(define empty-tenv empty-tenv-record)
(define extend-tenv extended-tenv-record)

(define apply-tenv 
  (lambda (tenv sym)
    (cases type-environment tenv
      (empty-tenv-record ()
                         (eopl:error 'apply-tenv "Unbound variable ~s" sym))
      (extended-tenv-record (sym1 val1 old-env)
                            (if (eqv? sym sym1) 
                                val1
                                (apply-tenv old-env sym))))))

(define init-tenv
  (lambda ()
    (extend-tenv 'x (int-type) 
                 (extend-tenv 'v (int-type)
                              (extend-tenv 'i (int-type)
                                           (empty-tenv))))))


;; type-of-program : Program -> Type
;; Page: 244
(define type-of-program
  (lambda (pgm)
    (cases program pgm
      (a-program (exp1) (type-of exp1 (init-tenv))))))

;; type-of : Exp * Tenv -> Type
;; Page 244--246
(define type-of
  (lambda (exp tenv)
    (cases expression exp
      (const-exp (num) (int-type))
      (var-exp (var) (apply-tenv tenv var))
      (diff-exp (exp1 exp2)
                (let ((ty1 (type-of exp1 tenv))
                      (ty2 (type-of exp2 tenv)))
                  (check-equal-type! ty1 (int-type) exp1)
                  (check-equal-type! ty2 (int-type) exp2)
                  (int-type)))
      (zero?-exp (exp1)
                 (let ((ty1 (type-of exp1 tenv)))
                   (check-equal-type! ty1 (int-type) exp1)
                   (bool-type)))
      (if-exp (exp1 exp2 exp3)
              (let ((ty1 (type-of exp1 tenv))
                    (ty2 (type-of exp2 tenv))
                    (ty3 (type-of exp3 tenv)))
                (check-equal-type! ty1 (bool-type) exp1)
                (check-equal-type! ty2 ty3 exp)
                ty2))
      (let-exp (var exp1 body)
               (let ((exp1-type (type-of exp1 tenv)))
                 (type-of body
                          (extend-tenv var exp1-type tenv))))
      (proc-exp (var var-type body)
                (let ((result-type
                       (type-of body
                                (extend-tenv var var-type tenv))))
                  (proc-type var-type result-type)))
      (call-exp (rator rand) 
                (let ((rator-type (type-of rator tenv))
                      (rand-type  (type-of rand tenv)))
                  (cases type rator-type
                    (proc-type (arg-type result-type)
                               (begin
                                 (check-equal-type! arg-type rand-type rand)
                                 result-type))
                    (else
                     (report-rator-not-a-proc-type rator-type rator)))))
      (letrec-exp (p-result-type p-name b-var b-var-type p-body
                                 letrec-body)
                  (let ((tenv-for-letrec-body
                         (extend-tenv p-name
                                      (proc-type b-var-type p-result-type)
                                      tenv)))
                    (let ((p-body-type 
                           (type-of p-body
                                    (extend-tenv b-var b-var-type
                                                 tenv-for-letrec-body)))) 
                      (check-equal-type!
                       p-body-type p-result-type p-body)
                      (type-of letrec-body tenv-for-letrec-body))))
      )))

(define report-rator-not-a-proc-type
  (lambda (rator-type rator)
    (eopl:error 'type-of-expression
                "Rator not a proc type:~%~s~%had rator type ~s"   
                rator 
                (type->string rator-type))))


;;; ======== ANYTHING BELOW THIS LINE IS SUPPORT CODE =========
(require racket/exn)
; for playing with programs in DrRacket
(define (test p)
  (begin
    (display "PROGRAM:\n")
    (display (program->string p))
    (display "\n")
    (display "TYPE:\n")
    (display (with-handlers ([(λ (e) #t) (λ (e) (exn->string e))]) (type->string (type-of-program p)) ))
    (display "\n")
    (display "evaluates to:\n")
    (display (with-handlers ([(λ (e) #t) (λ (e) (exn->string e))]) (expval->string (value-of-program p)) ))
    (display "\n----------------\n")))

;; PRETTY PRINTING
(require (rename-in pprint (empty ppempty)))

(define (program->doc pgm)
  (cases program pgm
    (a-program (exp1)
               (h-append (exp->doc exp1 ) line ))))

(define (exp->doc exp)
  (cases expression exp
    (const-exp (num) (text (number->string num)))
    (var-exp (var) (text (symbol->string var)))
    (diff-exp (exp1 exp2)
              (let ((val1 (exp->doc exp1))
                    (val2 (exp->doc exp2)))
                (group (h-append lparen space (align (h-append val1 line (char #\-) space (align (h-append val2 space rparen))))))))
    (zero?-exp (exp1)
               (let ((val1 (exp->doc exp1 )))
                 (hs-append (kw "zero?") lparen (align val1) rparen)))
    (if-exp (exp1 exp2 exp3)
            (let ((val1 (exp->doc exp1 ))
                  (val2 (exp->doc exp2 ))
                  (val3 (exp->doc exp3 )))
              (group (h-append
                      (kw "if")
                      space
                      (align val1)
                      line
                      (kw "then")
                      space
                      (align val2)
                      line
                      (kw "else")
                      space
                      (align val3) )))          )
    (let-exp (var exp1 body)       
             (let ((val1 (exp->doc exp1))
                   (val2 (exp->doc body)))
               (h-append
                (kw "let")
                space
                (text (symbol->string var))
                space
                equals
                space
                (align val1)
                line
                (kw "in")
                space
                (align val2)) ))
    (proc-exp (var ty body)
              (let ((val (exp->doc body)))
                (group (h-append
                 (kw "proc")
                 (align (h-append
                 lparen
                 (text (symbol->string var)) colon (text (type->string ty))
                 rparen
                 line
                 val))
                 ))))
    (call-exp (rator rand)
              (let ((val1 (exp->doc rator))
                    (val2 (exp->doc rand)))
                (group (h-append lparen space (align (h-append val1 line (align (h-append val2 space rparen))))))))
    (letrec-exp (rty p-name b-var pty p-body letrec-body)
                (let ((p-val (exp->doc p-body))
                      (letrec-val (exp->doc letrec-body)))
                  (h-append
                   (kw "letrec")
                   space
                   (text (type->string rty)) space (text (symbol->string p-name))
                   lparen
                   (text (symbol->string b-var)) colon (text (type->string pty))
                   rparen
                   space
                   equals
                   space
                   (align p-val)
                   line
                   (kw "in")
                   space
                   (align letrec-val)) ))
    ))

(define (program->string p)
  (pretty-format (program->doc p)))

(define (expval->string v)
  (pretty-format (expval->doc v)))

(define (env->html env)
  (define (iter env)
    (cases environment env
      (empty-env () `())
      (extend-env (bvar bval saved-env)
                  (cons `(tr (td ,(symbol->string bvar)) (td ,(expval->html bval)))
                        (iter saved-env)))            
      (extend-env-rec (p-name b-var p-body saved-env)
                    (cons `(tr (td ,(string-append (symbol->string p-name) "(" (symbol->string b-var) ")")) (td ,(exp->html p-body)))
                        (iter saved-env))  
                    )))
  (cons 'table (cons `((class "w3-border")) (iter env)))
    )

(define (expval->doc v)
  (cases expval v
    (bool-val (bool) (text (if bool "#t" "#f")))
    (num-val (n) (text (number->string n)))
    (proc-val (p) (cases proc p
                    (procedure (var body saved-env)
                               (addenv saved-env ; only add env when converting to HTML
                                       (let ((val (exp->doc body))) 
                                         (group (h-append
                                                 (kw "proc")
                                                 (align (h-append
                                                         lparen
                                                         (text (symbol->string var)) 
                                                         rparen
                                                         line
                                                         val))
                                                 )))))))                                                      
    ))

(define (kw s)
  (markup (lambda (x) `(b ,x)) (text s)))

(define (addenv env d)
  (markup (lambda (x) `(table (tr (td (pre ,x)) (td ,(env->html env))))) d))

(define (combine x1 x2)
  `(span ,x1 ,x2))

(define (program->html p)
  `(pre ,(pretty-markup (program->doc p) combine)))

(define (exp->html p)
  `(pre ,(pretty-markup (exp->doc p) combine 20)))

(define (expval->html v)
  (pretty-markup (expval->doc v) combine 20))

;; PARSING
(require (rename-in parsack (string pstring) (char pchar)))

(define ws (many (oneOf "\n \t\r"))) ; whitespace

(define (token s)
  (try (parser-compose
        ws
        (x <- (pstring s))
        ws
        (return x))))

(define KEYWORDS (list "in" "let" "zero?" "if" "then" "else" "proc" "letrec" "int" "bool"))

(define psymbol
  (try (parser-compose
   ws
   (x <- $identifier)
   (if (member (apply string x) KEYWORDS) $err ws)
   (return (string->symbol (apply string x))))))


(define pnumber
  (try (parser-compose
   ws
   (sign <- (<any> (>> (pchar #\-) (return #t)) (return #f)))
   (n <- (many1 $digit))
   (return (let [(v (string->number (apply string n)))] (if sign (- v) v) )))))

(define ptype
  (<any>
   (parser-compose (token "int")
                   (return (int-type)))
   (parser-compose (token "bool")
                   (return (bool-type)))
   (parser-compose
    (token "(")
    (ty1 <- ptype)
    (token "->")
    (ty2 <- ptype)
    (token ")")
    (return (proc-type  ty1 ty2)))   
   ))
(define exp-parser
  (<any>
   (parser-compose (n <- pnumber)
                   (return (const-exp n)))
   (try (parser-compose (token "(")
                        (e1 <- exp-parser)
                        (token "- "); NOTE space after - : (x-1) is parsed as x applied to -1
                        (e2 <- exp-parser)
                        (token ")")
                        (return (diff-exp e1 e2))))
   (try (parser-compose (token "(")
                        (e1 <- exp-parser)
                        ws
                        (e2 <- exp-parser)
                        (token ")")
                        (return (call-exp e1 e2))))
   (parser-compose (token "if")
                   (e1 <- exp-parser)
                   (token "then")
                   (e2 <- exp-parser)
                   (token "else")
                   (e3 <- exp-parser)
                   (return (if-exp e1 e2 e3)))
   (parser-compose (token "zero?")
                   (token "(")
                   (e <- exp-parser)
                   (token ")")
                   (return (zero?-exp e)))
   (parser-compose (token "letrec")
                   (rty <- ptype)
                   (p-name <- psymbol)
                   (token "(")
                   (v-name <- psymbol) (token ":") (pty <- ptype)
                   (token ")")
                   (token "=")
                   (p-body <- exp-parser)
                   (token "in")
                   (body <- exp-parser)
                   (return (letrec-exp rty p-name v-name pty p-body body)))   
   (parser-compose (token "let")
                   (v <- psymbol)
                   (token "=")
                   (e1 <- exp-parser)
                   (token "in")
                   (e2 <- exp-parser)
                   (return (let-exp v e1 e2)))
   (parser-compose (token "proc")
                   (token "(")
                   (v <- psymbol) (token ":") (ty <- ptype)
                   (token ")")
                   (body <- exp-parser)
                   (return (proc-exp v ty body)))
   (parser-compose (v <- psymbol)
                   (return (var-exp v)))
   )
  )

(define (string->program s)
  (a-program (parse-result exp-parser s)))

;;; Example programs
(require "CHECKED-examples.rkt")
(define examples
  (map (compose string->program second) examples-with-notes))

(define (p n) (list-ref examples n))

;; Web server for playing with programs
(require web-server/servlet
         web-server/servlet-env)

(define-values (dispatch to-url)
    (dispatch-rules
     [("") list-programs]
     [("edit") edit-program]
     [else list-programs]))

(define (list-programs req)
  (response/xexpr
   `(html
       (head
        (title "LETREC Programming Language")
        (link ((rel "stylesheet") (href "https://www.w3schools.com/w3css/4/w3.css"))))
       (body
        (div ((class "w3-container w3-responsive"))    
             (table ((class "w3-table-all"))
                    (tr (th "Description") (th "Program") (th "Type") (th "Result") (th "Edit"))
                    ,@(map (λ (p) `(tr
                                    (td ,(first p))
                                    (td (pre ,(program->html (string->program (second p)))))
                                    (td ,(with-handlers ([(λ (e) #t) (λ (e) (exn->string e))]) (type->string (type-of-program (string->program (second p)))) ))
                                    (td ,(with-handlers ([(λ (e) #t) (λ (e) (exn->string e))]) (expval->html (value-of-program (string->program (second p)))) ))
                                    (td (form ((action ,(to-url edit-program)))
                                              (input ((type "hidden") (name "prog") (value ,(second p))))
                                              (input ((type "submit") (value "Edit"))))
                                     )
                                    )) examples-with-notes )
                    
                    ))))
   )
  )
(define (edit-program req)
  (let* ((p-string (extract-binding/single 'prog (request-bindings req)))
        (p (string->program p-string)))
  (response/xexpr
   `(html
     (head
      (title "LETREC Programming Language")
      (link ((rel "stylesheet") (href "https://www.w3schools.com/w3css/4/w3.css"))))
     (body
      (div ((class "w3-container w3-responsive"))
           (p (a ((href ,(to-url list-programs))) "Back to list"))
           (table ((class "w3-table-all"))
                  (tr (th "Editable source"))
                  (tr (td (form 
              ((action ,(to-url edit-program))
               (class "w3-container"))
              (textarea ((class "w3-input w3-border") (rows "7") (name "prog")) ,p-string)
              (input ((type "submit"))))
                  (tr (th "Source Program") )
                  (tr (td (pre ,(program->html p))))
                  (tr (th "Type"))
                  (tr (td ,(with-handlers ([(λ (e) #t) (λ (e) (exn->string e))]) (type->string (type-of-program p)) )))
                  (tr (th "Result") )
                  (tr (td ,(with-handlers ([(λ (e) #t) (λ (e) (exn->string e))]) (expval->html (value-of-program p)) )))
                                  ) 
                  ))))
   ))))

(define (web) (serve/dispatch dispatch))
