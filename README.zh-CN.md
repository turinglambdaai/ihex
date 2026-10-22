# ihex — Intel HEX in pure Racket

[English](README.md) · **中文**

[![CI](https://github.com/turinglambdaai/ihex/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/ihex/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`ihex` 读取和写入 **Intel HEX** 文件——面向记录的固件映像格式，被 8051、MCS-96、ARM 以及无数其他目标平台的工具链使用。

全部以纯 Racket 实现：无 FFI，无系统依赖。写入器与 Python 的 [bincopy](https://github.com/eerimoq/bincopy) 做了逐字节对照验证（其输出作为黄金基准数据一并发布），且映像写入器比 bincopy 更进一步：数据记录绝不跨越 64K 地址窗口（记录的地址字段只有 16 位，跨窗记录将无法表示）——每次窗口切换处都会插入一条 extended-linear 记录。

## 安装

```
raco pkg install ihex
```

## 用法

```racket
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

### 记录

`ihex-record` 对应一行：`kind` 为 `'data`（00）、`'eof`（01）、`'extended-segment`（02）、`'start-segment`（03）、`'extended-linear`（04）或 `'start-linear`（05）。`parse-ihex` 强制校验完整语法——错误的数据长度、校验和不匹配、奇数长十六进制、未知类型、地址位置错误——并报告行号。

### 映像

`ihex->bytes` 将数据记录组装为一个字节串，套用 extended-linear 与 extended-segment 基址，用填充字节（默认 `#xFF`）填补空洞并拒绝重叠。`bytes->ihex` 渲染映像，支持可配置的行长度、窗口边界切分以及可选的 start-linear 记录。

## 许可证

[MIT](LICENSE)。
