# ihex — Intel HEX in pure Racket

[English](README.md) · **中文**

[![CI](https://github.com/turlamai/ihex/actions/workflows/ci.yml/badge.svg)](https://github.com/turlamai/ihex/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`ihex` 读取和写入 **Intel HEX** 文件——面向记录的固件映像格式，被 8051、MCS-96、ARM 以及无数其他目标平台的工具链使用。

全部以纯 Racket 实现：无 FFI，无系统依赖。写入器与 Python 的 [bincopy](https://github.com/eerimoq/bincopy) 做了逐字节对照验证（其输出作为黄金基准数据一并发布），且映像写入器比 bincopy 更进一步：数据记录绝不跨越 64K 地址窗口（记录的地址字段只有 16 位，跨窗记录将无法表示）——每次窗口切换处都会插入一条 extended-linear 记录。

## 安装

```
raco pkg install ihex
```

## 用法

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

### 记录

`ihex-record` 对应一行：`kind` 为 `'data`（00）、`'eof`（01）、`'extended-segment`（02）、`'start-segment`（03）、`'extended-linear`（04）或 `'start-linear`（05）。`parse-ihex` 强制校验完整语法——错误的数据长度、校验和不匹配、奇数长十六进制、未知类型、地址位置错误——并报告行号。

### 映像

`ihex->bytes` 将数据记录组装为一个字节串，套用 extended-linear 与 extended-segment 基址，用填充字节（默认 `#xFF`）填补空洞并拒绝重叠。`bytes->ihex` 渲染映像，支持可配置的行长度、窗口边界切分以及可选的 start-linear 记录。

## API 文档与开发

完整的记录模型、记录类型、解析和写入契约、地址窗口及错误处理请查阅
[Scribble API 文档](ihex/scribblings/ihex.scrbl)；文档中的
`scribble/example` 会在构建时真实执行。
[独立入门示例](examples/quickstart.rkt)用合成数据验证上面的映像往返和入口地址。

安装 Racket 及 `raco` 后，在仓库根目录运行：

```sh
raco pkg install --auto --link "$(pwd)"
raco test -p ihex
racket examples/quickstart.rkt
raco setup --check-pkg-deps -l ihex
```

CI 在 Linux、macOS、Windows 上检查这些步骤。`ihex` 是公开的
`require` 模块路径；使用本包读写固件映像不需要硬件、网络、厂商工具
或 Python 运行环境。如发现问题，请在
[GitHub Issues](https://github.com/turlamai/ihex/issues)
提交脱敏的最小记录示例，避免上传专有固件数据。

## 许可证

[MIT](LICENSE)。
