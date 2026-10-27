#lang racket/base
;; Executable documentation example: all data is synthetic.
(require ihex)

(define image (bytes #xDE #xAD #xBE #xEF))
(define text
  (bytes->ihex image
               #:base-address #x1000
               #:start-address #x1000))

(unless (equal? (ihex->bytes text) image)
  (error 'ihex-quickstart "round-trip image differs"))
(unless (= (ihex-start-address text) #x1000)
  (error 'ihex-quickstart "start address not preserved"))

;; A second round-trip makes sure the serialized records are parseable.
(unless (pair? (parse-ihex text))
  (error 'ihex-quickstart "records are missing"))

(displayln "Intel HEX quickstart OK")
