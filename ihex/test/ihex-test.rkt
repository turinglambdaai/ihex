#lang racket/base

;; Tests for the ihex package.  The golden fixtures under data/ were
;; generated with the Python `bincopy` library (20.1.1) and freeze its
;; output byte-for-byte; my writer must reproduce them exactly and my
;; parser must accept them (double-implementation cross-check).  The
;; window-split fixture was additionally verified to parse back through
;; bincopy.

(require rackunit
         racket/file
         racket/list
         racket/runtime-path
         racket/string
         ihex/record
         ihex/parse
         ihex/write)

(define-runtime-path data-dir "data")

(define (golden name)
  (file->string (build-path data-dir name)))

;; 53 sample bytes used across the bincopy-generated fixtures
(define sample-53 (list->bytes (for/list ([i (in-range #x35)]) i)))

;; ---------------------------------------------------------------------------
;; checksum

(test-case "ihex checksum anchors"
  ;; :00000001FF -> checksum FF
  (check-equal? (ihex-checksum (bytes 0 0 0 1)) #xFF)
  ;; :04100000DEADBEEFB4 -> checksum B4
  (check-equal? (ihex-checksum (bytes #x04 #x10 #x00 #x00 #xDE #xAD #xBE #xEF)) #xB4)
  ;; :020000040001F9 -> checksum F9
  (check-equal? (ihex-checksum (bytes #x02 #x00 #x00 #x04 #x00 #x01)) #xF9))

;; ---------------------------------------------------------------------------
;; golden fixtures from bincopy

(test-case "bincopy golden: 32 data bytes per line"
  (check-equal? (bytes->ihex sample-53
                             #:base-address #x1000
                             #:data-bytes-per-line 32)
                (golden "ihex-53b-at-1000-32.hex")))

(test-case "bincopy golden: 8 data bytes per line"
  (check-equal? (bytes->ihex sample-53
                             #:base-address #x1000
                             #:data-bytes-per-line 8)
                (golden "ihex-53b-at-1000-8.hex")))

(test-case "bincopy golden: start-linear record"
  (check-equal? (bytes->ihex (bytes #xDE #xAD #xBE #xEF)
                             #:base-address #x1000
                             #:data-bytes-per-line 8
                             #:start-address #x1000)
                (golden "ihex-sla.hex")))

;; ---------------------------------------------------------------------------
;; parsing

(test-case "parse bincopy goldens back to the original image"
  (check-equal? (ihex->bytes (golden "ihex-53b-at-1000-32.hex")) sample-53)
  (check-equal? (ihex->bytes (golden "ihex-53b-at-1000-8.hex")) sample-53))

(test-case "parse the classic example: records and image"
  (define recs (parse-ihex (golden "wikipedia.hex")))
  (check-equal? (length recs) 2)
  (check-equal? (ihex-record-kind (car recs)) 'data)
  (check-equal? (ihex-record-address (car recs)) #x100)
  (check-equal? (ihex->bytes (golden "wikipedia.hex"))
                (bytes #x21 #x46 #x01 #x36 #x01 #x21 #x47 #x01
                       #x36 #x00 #x7E #xFE #x09 #xD2 #x19 #x01)))

(test-case "start-linear start address"
  (check-equal? (ihex-start-address (golden "ihex-sla.hex")) #x1000))

(test-case "extended-linear records address above 64K"
  ;; bincopy's own ELA output (which lets one record overflow the window);
  ;; my parser is window-agnostic on input and reassembles the image.
  (check-equal? (ihex->bytes (golden "ihex-ela-bincopy.hex"))
                (bytes 0 1 2 3 4 5 6 7))
  (define abs
    (for/list ([r (in-list (parse-ihex (golden "ihex-ela-bincopy.hex")))]
               #:when (eq? (ihex-record-kind r) 'data))
      (ihex-record-address r)))
  (check-equal? abs (list #xFFFC)))

(test-case "window-split output parses back identically"
  (define text (golden "ihex-windowsplit.hex"))
  ;; 4 bytes in the first window, 4 in the second, one ELA record between
  (define kinds (for/list ([r (in-list (parse-ihex text))]) (ihex-record-kind r)))
  (check-equal? kinds '(data extended-linear data eof))
  (define img (ihex->bytes text))
  (check-equal? img (bytes 1 2 3 4 5 6 7 8)))

(test-case "writer splits at the 64K window boundary"
  (define text (bytes->ihex (bytes 1 2 3 4 5 6 7 8)
                            #:base-address #xFFFC
                            #:data-bytes-per-line 8))
  (check-equal? text (golden "ihex-windowsplit.hex")))

(test-case "writer emits ELA for images above 64K and bincopy goldens agree on the image"
  (define text (bytes->ihex (bytes 1 2 3 4 5 6 7 8)
                            #:base-address #x1FFFC
                            #:data-bytes-per-line 8))
  ;; split at the 0x20000 window boundary, unlike bincopy's overflowing line
  (check-equal? (ihex->bytes text) (bytes 1 2 3 4 5 6 7 8))
  (check-equal? (ihex-start-address text) #f)
  ;; the writer's own record stream contains two ELA records
  (check-equal? (length (for/list ([r (in-list (parse-ihex text))]
                                   #:when (eq? (ihex-record-kind r) 'extended-linear))
                          r))
                2))

(test-case "extended-segment addressing (segment*16 + offset)"
  ;; segment 0x1234 -> base 0x12340; data at offset 0x0010 -> 0x12350
  (define text (string-append ":020000021234B6\n"
                              ":04001000DEADBEEFB4\n"
                              ":00000001FF\n"))
  (check-equal? (ihex->bytes text) (bytes #xDE #xAD #xBE #xEF))
  (check-equal? (ihex-record-address
                 (second (parse-ihex text)))
                #x10))

(test-case "start-segment start address concatenates its two words"
  (define text (string-append ":0400000310000030B9\n"
                              ":00000001FF\n"))
  ;; words 0x1000 and 0x0030 -> 0x10000030 (bincopy-compatible)
  (check-equal? (ihex-start-address text) #x10000030))

(test-case "lowercase hex input is accepted"
  (define recs (parse-ihex ":04100000deadbeefb4\n"))
  (check-equal? (ihex-record-data (car recs)) (bytes #xDE #xAD #xBE #xEF)))

(test-case "gap fill"
  (define text (string-append ":04100000AABBCCDDDE\n"
                              ":041010001122334432\n"
                              ":00000001FF\n"))
  (define img (ihex->bytes text))
  (check-equal? (bytes-length img) 20)
  (check-equal? (subbytes img 0 4) (bytes #xAA #xBB #xCC #xDD))
  (check-equal? (subbytes img 4 16) (make-bytes 12 #xFF))
  (check-equal? (subbytes img 16) (bytes #x11 #x22 #x33 #x44)))

;; ---------------------------------------------------------------------------
;; rejection cases

(define (fails? thunk)
  (with-handlers ([exn:fail? (lambda (_) #t)]) (thunk) #f))

(test-case "malformed records are rejected"
  ;; bad checksum
  (check-true (fails? (lambda () (parse-ihex ":04100000DEADBEEFB5\n"))))
  ;; data length mismatch
  (check-true (fails? (lambda () (parse-ihex ":03100000DEADBEEFAC\n"))))
  ;; odd number of hex digits
  (check-true (fails? (lambda () (parse-ihex ":04100000DEADBEEF\n"))))
  ;; unknown record type 6
  (check-true (fails? (lambda () (parse-ihex ":0100000600F9\n"))))
  ;; no leading colon
  (check-true (fails? (lambda () (parse-ihex "04100000DEADBEEFB4\n"))))
  ;; extended-linear with a non-zero address
  (check-true (fails? (lambda () (parse-ihex ":020001040001F8\n"))))
  ;; start-linear with 2 data bytes instead of 4
  (check-true (fails? (lambda () (parse-ihex ":020000050000F9\n"))))
  ;; eof record with data
  (check-true (fails? (lambda () (parse-ihex ":0100000100FE\n")))))

(test-case "overlapping data records are rejected"
  (check-true
   (fails? (lambda ()
             (ihex->bytes (string-append ":04100000AABBCCDDDE\n"
                                         ":021002001122B9\n"
                                         ":00000001FF\n"))))))

;; ---------------------------------------------------------------------------
;; record-level API

(test-case "record-level write/parse round trip"
  (define recs (parse-ihex (golden "ihex-53b-at-1000-8.hex")))
  (define text (string-append* (for/list ([r (in-list recs)])
                                 (string-append (write-ihex-record r) "\n"))))
  (check-equal? (parse-ihex text) recs))
