700
((3) 0 () 2 ((q lib "ihex/main.rkt") (q 0 . 10)) () (h ! (equal) ((c def c (c (? . 0) q ihex-start-address)) q (1262 . 4)) ((c def c (c (? . 0) q struct:ihex-record)) c (? . 1)) ((c def c (c (? . 0) q write-ihex-record)) q (515 . 3)) ((c def c (c (? . 0) q ihex-record)) c (? . 1)) ((c def c (c (? . 0) q ihex-record?)) c (? . 1)) ((c def c (c (? . 0) q ihex-record-address)) c (? . 1)) ((c def c (c (? . 0) q parse-ihex-line)) q (390 . 4)) ((c def c (c (? . 0) q bytes->ihex)) q (588 . 11)) ((c def c (c (? . 0) q ihex-record-kind)) c (? . 1)) ((c def c (c (? . 0) q ihex-record-data)) c (? . 1)) ((c def c (c (? . 0) q ihex->bytes)) q (1141 . 4)) ((c def c (c (? . 0) q parse-ihex)) q (312 . 3))))
struct
(struct ihex-record (kind address data))
  kind : (or/c 'data
               'eof
               'extended-segment
               'start-segment
               'extended-linear
               'start-linear)
  address : exact-nonnegative-integer?
  data : bytes?
procedure
(parse-ihex text) -> (listof ihex-record?)
  text : string?
procedure
(parse-ihex-line line line-no) -> ihex-record?
  line : string?
  line-no : exact-nonnegative-integer?
procedure
(write-ihex-record rec) -> string?
  rec : ihex-record?
procedure
(bytes->ihex  bs                                          
             [#:base-address base                         
              #:data-bytes-per-line per-line              
              #:start-address start                       
              #:trailing-newline? trailing-newline?]) -> string?
  bs : bytes?
  base : exact-nonnegative-integer? = 0
  per-line : (integer-in 1 255) = 16
  start : (or/c exact-nonnegative-integer? #f) = #f
  trailing-newline? : boolean? = #t
procedure
(ihex->bytes text [#:fill fill]) -> bytes?
  text : string?
  fill : (integer-in 0 255) = 255
procedure
(ihex-start-address text)
 -> (or/c exact-nonnegative-integer? #f)
  text : string?
