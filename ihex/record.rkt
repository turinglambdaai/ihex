#lang racket/base

;; The Intel HEX data model: one struct per record line.

(require racket/contract)

(provide (contract-out
          (struct ihex-record ((kind (or/c 'data
                                           'eof
                                           'extended-segment
                                           'start-segment
                                           'extended-linear
                                           'start-linear))
                               (address exact-nonnegative-integer?)
                               (data bytes?)))))

(struct ihex-record (kind address data) #:transparent)
