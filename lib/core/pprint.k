;;;; Copyright (c) Jan Tolenaar. See the file LICENSE for details.

;;;;
;;;; pprint.k
;;;;

(defpackage "lisp"
    (:export
        "$pprint-left-margin"
        "$pprint-right-margin"
        "pprint"
    ))

(in-package "lisp")

(defconstant default-right-margin 80)
(defconstant default-indent-size 4)

(def $pprint-left-margin 0)
(def $pprint-right-margin default-right-margin)
(def $pprint-indent-size default-indent-size)

(defmacro with-indent ((offset) &body forms)
    `(do
        (let $pprint-left-margin (+ $pprint-left-margin ,offset))
        ,@forms))

(defmacro with-default-indent ((&optional (offset 0)) &body forms)
    `(with-indent ((+ default-indent-size ,offset)) ,@forms))

(def pprint-form-settings
    ;; The number is the number of expressions to keep on the same line as the keyword.
    '(
      (and 1 :align)
      (block 1)
      (break 1)
      (break-if 1)
      (case pprint-case)
      (case-match pprint-case)
      (catch 1)
      (cond pprint-cond)
      (continue 0)
      (continue-if 0)
      (def 2)
      (defconstant 2)
      (define-compiler-macro 2)
      (define-symbol-macro 2)
      (defmacro 2)
      (defmethod 2)
      (defmulti 2)
      (defonce 2)
      (defpackage 1)
      (defun 2)
      (defun* 1)
      (defsetf 1)
      (do 0)
      (merging-do 0)
      (ecase pprint-case)
      (ecase-match pprint-case)
      (etypecase pprint-case)
      (future 2)
      ;(if 1)
      (if pprint-if)
      (if-match 2)
      (ignore-errors 0)
      (lambda 1)
      (lambda* 0)
      (lazy 2)
      (let 2)
      (letfun 2)
      (letmacro 2)
      (let-symbol-macro 2)
      (loop 0)
      ;(new 1 :align)
      (new pprint-new)
      (or 1 :align)
      (psetf 2)
      (psetq 2)
      (quote 1)
      (return 1)
      (return-from 2)
      (return-if 1)
      (return-or-throw 1)
      (set 2)
      (setf 2)
      (setq 2)
      (throw 1)
      (try 0)
      (try-and-catch 0)
      (typecase pprint-case)
      (let 2)
      (var 2)
      (multiple-let 2)
      (multiple-var 2)
      (multiple-setf 2)
      (when 1)
      (when-match 2)
      (while 1)
     ))

(defun pprint (expr &key (left $pprint-left-margin) (right $pprint-right-margin))
"""
The pretty printer must write to $stdout and obey the settings of
$print-escape and $print-base.
"""
    ;;(let $print-compact true)
    (let $pprint-left-margin (or left 0))
    (let $pprint-right-margin (or right default-right-margin))
    (pprint-expr expr))

;;;
;;; Pretty printing implementation.
;;;

(defun pprint-expr (expr)
    (cond
        ((cons? expr)
            (pprint-cons expr))
        ((and (vector? expr) (not $print-vector-with-brackets))
            (pprint-sequence expr "#v(" ")"))
        ((ilist? expr)
            (pprint-sequence expr "[" "]"))
        ((prototype? expr)
            (pprint-prototype expr))
        (true
            (pprint-object expr))))

(defun pprint-cons (expr)

    (when (and $print-compact
               (pprint-cons-try-compact expr))
        (return))

    (let a (first expr))
    (let sym (and (symbol? a)
                  a))

    (var config (rest (find sym pprint-form-settings :key first)))
    (if (and config
             (not (rest config)))
        (setf (rest config) '(:indent)))

    (cond
        ((not config)
            (let func-like (and sym
                                (defined? sym)
                                (function? (symbol-value sym))))
            (if func-like
                  (pprint-code expr '(1 :align))
                (pprint-sequence expr "(" ")")
            ))
        ((function? (first config))
            (funcall (first config) expr))
        ((symbol? (first config))
            (funcall (symbol-value (first config)) expr))
        (true
            (pprint-formatted-code expr config))))

(defun pprint-cons-try-compact (expr)

    (let a (first expr))
    (let b (second expr))
    (let c (third expr))
    (let d (fourth expr))

    (when (eq a 'quote)
        (print "'")
        (with-indent (1)
            (pprint-expr b))
        (return true))

    (when (eq a 'quasi-quote)
        (print "`")
        (with-indent (1)
            (pprint-expr b))
        (return true))

    (when (eq a 'system:unquote)
        (print ",")
        (with-indent (1)
            (pprint-expr b))
        (return true))

    (when (eq a 'system:unquote-splicing)
        (print ",@")
        (with-indent (2)
            (pprint-expr b))
        (return true))

    (when (eq a 'system:pretty-reader)
        (case b
            (("#+" "#-")
                (print b)
                (print c)
                (print-line)
                (pprint d))
            (("literally" "line-comment" "block-comment" "string")
                (print c))
        )
        (return true))

    (when (and (eq a '.)
               (string? b)
               (null? c))
            (print "." b)
            (return true))

    (when (and (eq a '?)
               (string? b)
               (null? c))
            (print "?" b)
            (return true))

    (return false))

(defun pprint-sequence (expr leftpar rightpar)
    (let text (write-to-string expr))
    (cond
        ((<= (+ $pprint-left-margin (length text)) $pprint-right-margin)
            (write text :escape false))
        (true
            (pprint-formatted-list expr leftpar rightpar))))

(defun pprint-object (expr)
    (write expr :force false))

(defun pprint-prototype (expr)
    (let types (prototype:get-type-specifier expr))
    (let suffix (if types (write-to-string types)))
    (cond
        ($print-prototype-with-braces
            (pprint-formatted-list expr "{${suffix} " " }"))
        (true
            (pprint-formatted-list expr "#s(${suffix} " " )"))))

(defun pprint-formatted-list (seq leftpar rightpar)
    (print leftpar)
    (with-indent ((length leftpar))
        (pprint-items-vertically seq false))
    (print rightpar))

(defun pprint-code (expr config)
    (let text (write-to-string expr))
    (cond
        ((<= (+ $pprint-left-margin (length text)) $pprint-right-margin)
            (write text :escape false))
        (true
            (pprint-formatted-code expr config))))

(defun pprint-if (expr)
    (multiple-let (operator test then else) expr)
    (print "(" operator " ")
    (with-default-indent ()
        (pprint test)
        (print-line)
        (pprint-left-margin)
        (cond
            (else
                (print "  ")
                (with-indent (2)
                    (pprint then))
                (print-line)
                (pprint-left-margin)
                (pprint else))
            (true
                (pprint then))))
    (print ")"))

(defun pprint-cond (expr)
    (print "(" (first expr) " ")
    (with-default-indent ()
        (loop
            (for cond-case in (rest expr))
            (print-line)
            (pprint-left-margin)
            (print "(")
            (with-indent (1)
                (pprint (first cond-case))
                (with-default-indent ()
                    (pprint-items-vertically (rest cond-case) true)))
            (print ")")))
    (print ")"))

(defun pprint-case (expr)
    (let target (second expr))
    (let cases (rest (rest expr)))
    (print "(" (first expr) " ")
    (with-default-indent (2)
        (pprint target))
    (with-default-indent ()
        (loop
            (for case in cases)
            (print-line)
            (pprint-left-margin)
            (print "(")
            (with-indent (1)
                (pprint (first case))
                (with-default-indent ()
                    (pprint-items-vertically (rest case) true)))
            (print ")")))
    (print ")"))

(defun pprint-new (expr)
    (let seq (rest expr))
    (let len (length seq))
    (cond
        ((odd? len)
            (print "(new ")
            (with-indent (5)
                (pprint (first seq))
                (pprint-new-kv (rest seq) true)))
        (true
            (print "(new ")
            (with-indent (5)
                (pprint-new-kv seq false))))
    (print ")"))

(defun pprint-new-kv (seq newline)
    (loop
        (for kv in (partition 2 seq))
        (when newline
            (print-line)
            (pprint-left-margin))
        (let key (write-to-string (first kv)))
        (print key " ")
        (with-indent ((inc (length key)))
            (pprint (second kv)))
        (setf newline true)))

(defun pprint-formatted-code (expr config)
    (let num-items (first config))
    (print "(")
    (let head (write-to-string (first expr)))
    (var tail (rest expr))
    (write head :escape false)
    (let $pprint-left-margin
            (if (find :align (rest config))
                  (+ $pprint-left-margin 1 (.length head) 1)
                (+ $pprint-left-margin $pprint-indent-size)))
    (var left $pprint-left-margin)
    (loop
        (for i :in (series num-items))
        (print " ")
        (if (= i num-items)
            (pprint (first tail) :left (inc left))
          (do
            (let text (write-to-string (first tail)))
            (write text :escape false)
            (setf left (+ left 1 (.length text)))))
        (setf tail (rest tail)))
    (pprint-items-vertically tail true)
    (print ")"))


(defun pprint-items-vertically (seq newline)
    (cond
        ((cons? seq)
            (pprint-cons-items-vertically seq newline))
        ((prototype? seq)
            (pprint-prototype-items-vertically seq newline))
        (true
            (pprint-vector-items-vertically seq newline))))

(defun pprint-cons-items-vertically (seq newline)
    (loop
        (break-if (= null seq))
        (when newline
            (print-line)
            (pprint-left-margin))
        (setf newline true)
        (pprint-expr (car seq))
        (break-if (not (forced? seq)))
        (setf seq (cdr seq)))
    (when seq
        (print-line)
        (pprint-left-margin)
        (print "...")))

(defun pprint-vector-items-vertically (seq newline)
    (loop
        (for item in seq)
        (when newline
            (print-line)
            (pprint-left-margin))
        (setf newline true)
        (pprint-expr item)))

(defun pprint-prototype-items-vertically (seq newline)
    (loop
        (for key in (sort (prototype:keys seq)))
        (when newline
            (print-line)
            (pprint-left-margin))
        (setf newline true)
        (let head (string (if (.starts-with key "[") "" ":") key " "))
        (print head)
        (let $pprint-left-margin (+ $pprint-left-margin (.length head)))
        (pprint-expr (attr seq key))))

(defun pprint-left-margin ()
    (write "" :width $pprint-left-margin :escape false))

;;;
;;; This wires Kiezellisp's internal WRITE to PPRINT.
;;;

(setq $pprint-hook pprint)

;;;
;;; Lisp Syntax Colors
;;;

(defconstant $syntax-color-builtin 		0x0000ff)
(defconstant $syntax-color-comment 		0xb22222)
(defconstant $syntax-color-form 		0xda70d6)
(defconstant $syntax-color-constant 	0x0000ff)
(defconstant $syntax-color-special 		0x408080)
(defconstant $syntax-color-keyword 		0xa020f0)
(defconstant $syntax-color-ampersand 	0x228b22)
(defconstant $syntax-color-string 		0xbc7711)
(defconstant $syntax-color-conditional  0xb22222)
(defconstant $syntax-color-debug        0x0000ff)
