#lang racket/base

;; Intel HEX writer: record-level rendering plus image-level helpers.
;; Image rendering inserts extended-linear records whenever a data line
;; would cross a 64K address window (the record's address field is 16 bits,
;; so a line that straddles a window boundary would be unrepresentable).

(require racket/contract
         racket/string
         "record.rkt"
         "parse.rkt")

(provide (contract-out
          [write-ihex-record (-> ihex-record? string?)]
          [bytes->ihex
           (->* (bytes?)
                (#:base-address exact-nonnegative-integer?
                 #:data-bytes-per-line (integer-in 1 255)
                 #:start-address (or/c exact-nonnegative-integer? #f)
                 #:trailing-newline? boolean?)
                string?)]
          [ihex->bytes
           (->* (string?)
                (#:fill (integer-in 0 255))
                bytes?)]
          [ihex-start-address (-> string? (or/c exact-nonnegative-integer? #f))]))

(define (byte->hex2 b)
  (define s (string-upcase (number->string b 16)))
  (if (< b 16) (string-append "0" s) s))

(define (bytes->hex-up bs)
  (string-append* (for/list ([b (in-bytes bs)]) (byte->hex2 b))))

(define (be-bytes v n)
  (list->bytes
   (for/list ([i (in-range (sub1 n) -1 -1)])
     (bitwise-and (arithmetic-shift v (* -8 i)) #xFF))))

(define (render kind address data)
  (define type
    (case kind
      [(data) 0] [(eof) 1] [(extended-segment) 2]
      [(start-segment) 3] [(extended-linear) 4] [else 5]))
  (define body
    (bytes-append (bytes (bytes-length data))
                  (be-bytes address 2)
                  (bytes type)
                  data))
  (string-append ":"
                 (bytes->hex-up body)
                 (byte->hex2 (ihex-checksum body))))

;; Render one record line (no newline).
(define (write-ihex-record rec)
  (define kind (ihex-record-kind rec))
  (unless (or (eq? kind 'data) (zero? (ihex-record-address rec)))
    (error 'write-ihex-record "record type ~a must have address 0" kind))
  (render kind (ihex-record-address rec) (ihex-record-data rec)))

;; The upper 16 bits of an absolute address.
(define (window-of abs) (arithmetic-shift abs -16))

;; Render a whole memory image.  Data lines never cross a 64K window: a
;; fresh extended-linear record is emitted each time the window changes.
;; The EOF record always terminates the file, and an optional start-linear
;; record carries the entry address.
(define (bytes->ihex bs
                     #:base-address [base 0]
                     #:data-bytes-per-line [per-line 16]
                     #:start-address [start #f]
                     #:trailing-newline? [trailing-newline? #t])
  (define lines '())
  (define last-window #f)
  (define (emit-window! abs)
    (define w (window-of abs))
    ;; window 0 needs no extended-linear record until a later window
    ;; forces a switch back to it
    (unless (or (equal? w last-window)
                (and (zero? w) (not last-window)))
      (set! lines (cons (render 'extended-linear 0 (be-bytes w 2)) lines))
      (set! last-window w)))
  (for ([offset (in-range 0 (bytes-length bs) per-line)])
    (define abs (+ base offset))
    (define line-end (min (bytes-length bs) (+ offset per-line)))
    ;; split the line so it does not cross into the next 64K window
    (let loop ([offset offset] [abs abs])
      (define remaining (- line-end offset))
      (define room (- #x10000 (remainder abs #x10000)))
      (define take (min remaining room))
      (emit-window! abs)
      (set! lines
            (cons (render 'data
                          (remainder abs #x10000)
                          (subbytes bs offset (+ offset take)))
                  lines))
      (when (< take remaining)
        (loop (+ offset take) (+ abs take)))))
  (when start
    (unless (< start (arithmetic-shift 1 32))
      (error 'bytes->ihex "start address ~a does not fit in 32 bits" start))
    (set! lines (cons (render 'start-linear 0 (be-bytes start 4)) lines)))
  (set! lines (cons (render 'eof 0 #"") lines))
  (string-append (string-join (reverse lines) "\n")
                 (if trailing-newline? "\n" "")))

;; Assemble the data records into one byte string, applying extended-linear
;; and extended-segment bases.  Gaps are filled with `fill`; overlapping
;; records are an error; eof and start records are ignored.
(define (ihex->bytes text #:fill [fill #xFF])
  (define upper #f)      ; extended-linear base
  (define segment #f)    ; extended-segment base
  (define placed '())    ; (list (cons absolute-address bytes))
  (for ([r (in-list (parse-ihex text))])
    (case (ihex-record-kind r)
      [(extended-linear)
       (set! upper (big-endian (ihex-record-data r)))
       (set! segment #f)]
      [(extended-segment)
       (set! segment (* (big-endian (ihex-record-data r)) 16))
       (set! upper #f)]
      [(data)
       (define abs
         (cond [upper (+ (* upper #x10000) (ihex-record-address r))]
               [segment (+ segment (ihex-record-address r))]
               [else (ihex-record-address r)]))
       (set! placed (cons (cons abs (ihex-record-data r)) placed))]
      [else (void)]))
  (when (null? placed)
    (error 'ihex->bytes "no data records in input"))
  (define sorted (sort placed < #:key car))
  (define image-start (car (car sorted)))
  (define image-end
    (for/fold ([end 0]) ([p (in-list sorted)])
      (max end (+ (car p) (bytes-length (cdr p))))))
  (define out (make-bytes (- image-end image-start) fill))
  (for ([a (in-list sorted)]
        [b (in-list (cdr sorted))])
    (when (> (+ (car a) (bytes-length (cdr a)))
             (car b))
      (error 'ihex->bytes "records overlap at address ~a" (car b))))
  (for ([p (in-list sorted)])
    (bytes-copy! out (- (car p) image-start) (cdr p)))
  out)

(define (big-endian bs)
  (for/fold ([v 0]) ([b (in-bytes bs)])
    (+ (* v 256) b)))

;; The start (entry) address declared by a start-linear record (the 32-bit
;; big-endian word) or a start-segment record (its two 16-bit words
;; concatenated big-endian, matching bincopy).  Later records win.
(define (ihex-start-address text)
  (for/first ([r (in-list (reverse (parse-ihex text)))]
              #:when (memq (ihex-record-kind r) '(start-linear start-segment)))
    (define d (ihex-record-data r))
    (big-endian d)))
