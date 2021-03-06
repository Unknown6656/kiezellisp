;;;; Copyright (c) Jan Tolenaar. See the file LICENSE for details.


(defpackage "csv"
    (:use
        "lisp")
	(:export
        "$options"
        "convert-to-date"
        "convert-to-default"
        "convert-to-number"
        "DATE"
        "NUMBER"
        "read-grid-line-to-record"
        "read-grid-to-records"
        "read-grid-to-subgrid"
        "read-string-to-grid"
        "read-string-to-records"
        "write-grid-to-string"
        "write-records-to-grid"
        "write-records-to-string"
        "write-value-to-string"
    ))


(in-package "csv")


;;;
;;; Comma Separated Values
;;;

(def $options (new

    :quote-character "\""
    :field-separator ","
    :culture (culture-info:new "en-us")
    :trim-spaces? true
))

;;;
;;; Conversion macros
;;;

(defmacro DATE (field)
    `(setf ,field (convert-to-date ,field)))

(defmacro NUMBER (field)
    `(when (not (number? ,field))
        (setf ,field (convert-to-number (or ,field "0")))))

;;;
;;; Reading csv grids
;;;

(defun read-string-to-records (text &rest args)
    (let options (find-in-property-list :options args))
    (do 
        (read-string-to-grid text options)
        (apply read-grid-to-subgrid (list* ~ args))
        (apply read-grid-to-records (list* ~ args))))

(defun read-grid-to-records (grid &key prototype headers)
    (when (not headers)
        (setf headers (map cleanup-header (first grid)))
        (setf grid (rest grid)))
    (map #(read-grid-line-to-record prototype headers %1) grid))

(defun read-grid-line-to-record (prototype headers fields)
    (let record (new prototype))
    (loop
        (for h in headers)
        (for f in fields)
        (when h
            (setf (elt record h) f)))
    record)

(defun read-grid-to-subgrid (grid &key keep-empty-lines?
                                       (top 0)
                                       (left 0)
                                       (width int32:MAX-VALUE)
                                       (height int32:MAX-VALUE))
    (do 
        (subseq grid top :count height)
        (map #(subseq %1 left :count width) ~)
        (if keep-empty-lines?
              ~
            (filter boolean ~))))

;;;
;;; Writing csv grids
;;;

(defun write-records-to-string (records headers &key (options $options))
    (let grid (write-records-to-grid records headers))
    (write-grid-to-string grid options))

(defun write-records-to-grid (records headers)
    (append
        (vector headers)
        (map (lambda (record)
                (map (lambda (name) (elt record name))
                     headers))
            records)))


;;;
;;; conversions
;;;

(defun convert-to-default (text &optional (options $options))
    (let culture (.culture options))
    (let date-pattern (.short-date-pattern (.date-time-format culture)))
    (or (.try-parse-number text :culture culture :base 10)
        (.try-parse-date text :format date-pattern
                              :culture culture)
        text))

(defun convert-to-date (text &optional (options $options))
    (let culture (.culture options))
    (let date-pattern (.short-date-pattern (.date-time-format culture)))
    (or (.try-parse-date text :format  date-pattern
                              :culture culture)
        text))

(defun convert-to-number (text &optional (options $options))
    (let culture (.culture options))
    (or (.try-parse-number text :culture culture :base 10)
        text))

(defun cleanup-header (text)
    (do text
        (.trim ~)
        (.to-lower ~)
        (.replace ~ " " "-")
        (.replace ~ "_" "-")
        (.replace ~ "." "")
        (.replace ~ "," "")))



