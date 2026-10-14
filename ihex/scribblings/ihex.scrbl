#lang scribble/manual
@(require (for-label racket/base
                     racket/contract
                     ihex)
          scribble/example)

@(define ihex-eval (make-base-eval #:lang 'racket/base '(require ihex)))

@title[#:tag "ihex"]{ihex: Intel HEX files}
@author{turinglambdaai}

@defmodule[ihex]

The @filepath{ihex} package reads and writes @deftech{Intel HEX} files —
the record-oriented firmware image format used by toolchains for 8051,
MCS-96, ARM and countless other targets.  Everything is implemented in
pure Racket: no FFI, no system dependency.

The writer is validated byte-for-byte against the Python
@hyperlink["https://github.com/eerimoq/bincopy"]{@tt{bincopy}} library
(its outputs ship as golden fixtures), and the parser accepts everything
@tt{bincopy} produces.  The image writer goes one step further than
@tt{bincopy}: data records never cross a 64K address window (a record's
address field is only 16 bits, so a straddling record would be
unrepresentable) — an extended-linear record is inserted at every window
change.

@section{Quick start}

@examples[
#:eval ihex-eval
(define image (bytes #xDE #xAD #xBE #xEF))
(define text (bytes->ihex image
                          #:base-address #x1000
                          #:start-address #x1000))
(display text)
(ihex->bytes text)
(ihex-start-address text)
]

@section{Records}

A record line is @tt{:}<length>@tt{<address>}<type>@tt{<data><checksum>},
all hexadecimal, with a two's-complement checksum over length, address,
type and data — @racket[ihex-checksum].  Record types: @tt{00} data,
@tt{01} end-of-file, @tt{02} extended segment address
(@tt{segment × 16 + offset}), @tt{03} start segment address,
@tt{04} extended linear address (upper 16 bits of a 32-bit address) and
@tt{05} start linear address (a 32-bit entry point).

@defstruct*[ihex-record ([kind (or/c 'data
                                     'eof
                                     'extended-segment
                                     'start-segment
                                     'extended-linear
                                     'start-linear)]
                         [address exact-nonnegative-integer?]
                         [data bytes?])]{
 One record line.  Non-data records are validated structurally on parse:
 their address must be 0 and their data length fixed (2 bytes for the
 extended-address records, 4 for the start records, 0 for end-of-file).
}

@defproc[(parse-ihex [text string?]) (listof ihex-record?)]{
 Parses a whole file.  Blank lines are skipped and @tt{\r\n} endings are
 accepted.  Grammar violations — bad data lengths, checksum mismatches,
 odd hex, unknown record types, misplaced addresses — raise
 @racket[exn:fail] with the line number.
}

@defproc[(parse-ihex-line [line string?]
                          [line-no exact-nonnegative-integer?])
         ihex-record?]{
 Parses one record line; @racket[line-no] only appears in error messages.
}

@section{Writing}

@defproc[(write-ihex-record [rec ihex-record?]) string?]{
 Renders one record line (no newline).  Non-data records must carry
 address 0.
}

@defproc[(bytes->ihex [bs bytes?]
                      [#:base-address base exact-nonnegative-integer? 0]
                      [#:data-bytes-per-line per-line (integer-in 1 255) 16]
                      [#:start-address start (or/c exact-nonnegative-integer? #f) #f]
                      [#:trailing-newline? trailing-newline? boolean? #t])
         string?]{
 Renders a complete image: data records split on the configured line
 length and at 64K window boundaries (each window change emits an
 extended-linear record), the optional start-linear record and the
 end-of-file record.
}

@section{Images}

@defproc[(ihex->bytes [text string?] [#:fill fill (integer-in 0 255) #xFF])
         bytes?]{
 Assembles the data records into one byte string, applying
 extended-linear and extended-segment bases.  Gaps are filled with
 @racket[fill]; overlapping records are an error; end-of-file and start
 records are ignored.
}

@defproc[(ihex-start-address [text string?])
         (or/c exact-nonnegative-integer? #f)]{
 The entry address of the last start record: the 32-bit big-endian word
 of a start-linear record, or the two 16-bit words of a start-segment
 record concatenated big-endian (the same interpretation @tt{bincopy}
 uses).  @racket[#f] when the file declares no start address.
}

@section{License}

MIT.
