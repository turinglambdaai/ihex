# ihex — Intel HEX in pure Racket

**English** · [中文](README.zh-CN.md)

[![CI](https://github.com/turinglambdaai/ihex/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/ihex/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`ihex` reads and writes **Intel HEX** files — the record-oriented firmware
image format used by toolchains for 8051, MCS-96, ARM and countless other
targets.

Everything is implemented in pure Racket: no FFI, no system dependency.
The writer is validated byte-for-byte against Python's
[bincopy](https://github.com/eerimoq/bincopy) (its outputs ship as golden
fixtures), and the image writer goes one step further than bincopy: data
records never cross a 64K address window (a record's address field is only
16 bits, so a straddling record would be unrepresentable) — an
extended-linear record is inserted at every window change.

## Installation

```
raco pkg install ihex
```

## Usage

```racket
#lang racket/base
(require ihex)

(define image (bytes #xDE #xAD #xBE #xEF))
(define text (bytes->ihex image
                          #:base-address #x1000
                          #:start-address #x1000))
;; :04100000DEADBEEFB4
;; :0400000500001000E7
;; :00000001FF

(ihex->bytes text)          ; => #"\336\255\276\357"
(ihex-start-address text)   ; => 4096
```

### Records

`ihex-record` models one line: `kind` is `'data` (00), `'eof` (01),
`'extended-segment` (02), `'start-segment` (03), `'extended-linear` (04)
or `'start-linear` (05).  `parse-ihex` enforces the full grammar — bad
data lengths, checksum mismatches, odd hex, unknown types, misplaced
addresses — and reports the line number.

### Images

`ihex->bytes` assembles the data records into one byte string, applying
extended-linear and extended-segment bases, filling gaps with a fill byte
(default `#xFF`) and rejecting overlaps.  `bytes->ihex` renders an image
with configurable line length, window-boundary splitting and an optional
start-linear record.

## API documentation and development

The [Scribble API reference](ihex/scribblings/ihex.scrbl) defines the
record model, accepted record types, exact parser and writer contracts, address
windows and error conditions. Its quickstart uses `scribble/example` and is
evaluated during documentation builds. The
[executable quickstart](examples/quickstart.rkt) independently verifies the
README's image round-trip and entry-point results with synthetic data.

From the repository root, with Racket and `raco` installed:

```sh
raco pkg install --auto --link "$(pwd)"
raco test -p ihex
racket examples/quickstart.rkt
raco setup -l ihex --check-pkg-deps
```

These steps are covered by the Linux/macOS/Windows CI matrix. Racket module
path `ihex` is the public API, and neither parsing nor formatting needs
hardware, network, a vendor toolchain or Python at runtime. For bugs, submit
a minimal record reproducer (no proprietary firmware) to
[GitHub Issues](https://github.com/turinglambdaai/ihex/issues).

## License

[MIT](LICENSE).
