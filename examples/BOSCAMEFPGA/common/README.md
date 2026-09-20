# Shared NR FPGA Platform Sources

Files in this directory are reused by examples under `examples/BOSCAMEFPGA`.
They are vendored here; building does not require a local ModelZoo clone.

```text
common/
├── toolchain.mk          # LLVM tool selection (override with make NAME=value)
├── uart/                 # Shared NR UART driver (hello and operators)
│   ├── uart.h
│   └── uart.c
├── runtime/              # Hello: NH-only CRT and C runtime
│   ├── crt_uart.S
│   ├── encoding.h
│   ├── bare_runtime.h
│   └── bare_runtime.c
└── nr/                   # Operators: NH starts RA (see nr/README.md)
    ├── crt.S
    ├── nr.ld
    ├── nr_runtime.c / .h
    ├── nr_math.c
    ├── ame_sync.c
    └── nr_copy.S
```

| Path | Role |
| --- | --- |
| [`uart/uart.h`](uart/uart.h), [`uart/uart.c`](uart/uart.c) | NR UART: base `0x310b0000`, 32-bit MMIO, TX `+0x20`, LSR `+0x14`, fixed divisor 8. Shared. Hello compiles `uart.c`; the NR runtime includes the same headers and owns MMIO on NH. |
| [`runtime/`](runtime/bare_runtime.c) | Hello only. Single-hart NH CRT: registers, BSS, `main()`, no RA. |
| [`nr/`](nr/README.md) | Operators such as `qwen3-0.6b/add_1x1024`. NH initializes UART and starts RA; RA runs `launch()`. Do not link `runtime/` and `nr/` in one image. |
| [`toolchain.mk`](toolchain.mk) | `RISCV_CC` / `RISCV_LD` / `RISCV_OBJCOPY` / `RISCV_OBJDUMP`; included by example makefiles |

## Toolchain

[`toolchain.mk`](toolchain.mk) is written for an example one directory below
`BOSCAMEFPGA` (`REPO_ROOT ?= ../../..`). It uses `llvm/build/bin/clang` when
that file exists, otherwise tools from `PATH`. A missing tool in the chosen
directory (for example `ld.lld`) also falls back to `PATH`.

```bash
# LLVM_BIN is relative to the example directory unless it is absolute.
make -C examples/BOSCAMEFPGA/hello LLVM_BIN=../../../llvm/build/bin all

# Use only tools on PATH.
make -C examples/BOSCAMEFPGA/hello LLVM_BIN= all
```

Required: clang with RV64, LLD, llvm-objcopy. llvm-objdump is used for
`make dump`. After changing the toolchain or `CFLAGS`, run `make clean`.

## UART and startup

- UART is 8N1 with a **fixed divisor of 8**, matching a 14.7456 MHz clock at
  115200 baud. `init_uart(freq, baud)` keeps those arguments for API
  compatibility and ignores them. Hello and NR operators share these headers.
- Hello's `crt_uart.S` does not hard-code UART or DDR addresses. Memory layout
  comes from [`hello/platform/hello_nr.ld`](../hello/platform/hello_nr.ld).
- Hello flow: clear BSS / TBSS → `_init` → `init_uart` → banner → `main` →
  after-main → `wfi`. Operators use [`nr/crt.S`](nr/crt.S) and [`nr/nr.ld`](nr/nr.ld)
  instead; NH still owns UART MMIO.

An NH-only linker script must define `_start`, `__global_pointer$`,
`__stack_top`, and the BSS / TBSS bounds. See
[`hello/platform/hello_nr.ld`](../hello/platform/hello_nr.ld).

## Hello runtime (`runtime/`)

`hello` is a plain-C program: `_init` initializes UART, calls the weak banner /
before-main / after-main hooks, runs `main()`, then waits in `wfi`. The CRT
still vectors traps to `handle_trap`, which prints `mcause` / `mepc` / `mtval`
and hangs. There is no heap, `malloc`, MLIR `memrefCopy`, AME, or cycle-trace
support in this runtime.

## Operator runtime (`nr/`)

Linalg operators do not use `runtime/`. They include
[`../qwen3-0.6b/common.mk`](../qwen3-0.6b/common.mk), which compiles the objects
under [`nr/`](nr/README.md) and links [`nr/nr.ld`](nr/nr.ld). UART headers are
the same files in `uart/`; only NH touches the UART device.

## Provenance

Adapted from [ModelZoo](https://gitlink.org.cn/michaelcjl/ModelZoo) commit
`8815b74fb6d3cd6288c4d99ac6fd7c5d041a7cc3`:

| This tree | ModelZoo source |
| --- | --- |
| `uart/` | `thirdparty/nr/src/uart.c`, `thirdparty/nr/include/uart.h` |
| `runtime/crt_uart.S`, `encoding.h` | `thirdparty/platform-v01/` |
| `runtime/bare_runtime.c`, `.h` | `examples/tools/bare_runtime.c`, `bare_runtime.h` |
| `nr/` | `thirdparty/nr` and FPGA platform NH/RA sources (see [`nr/README.md`](nr/README.md)) |
| `../tools/ame_to_word.py` | `examples/tools/ame_to_word.py` |
| `../tools/restrict_fpga_assembly.py`, `nr_isa.py` | `examples/buddy-qwen35-fpga/python/qwen35/compiler/` |
| `../tools/check_nr_elf.py` | Example-side ELF audit using the ModelZoo-adapted ISA tables |
| `../qwen3-0.6b/` | Operator suite (`common.mk`, `support.*`, `add_1x1024`, host tools) |

Buddy-authored files in this tree that are not ModelZoo adaptations (for
example `hello/hello.c` and `toolchain.mk`) carry an Apache-2.0 header.
Vendored and adapted ModelZoo sources use a short file banner that names the
origin. **This tree does not invent license text for those sources**; file
headers and this table record provenance only. The CRT comments still refer to
`riscv-dnn/include/common/crt.S`.

Since import, the files have been formatted, UART implementation moved into
`uart.c` / shared `uart.h` helpers, and the assembly weak `_init` / gem5
`_exit` stubs removed so C `_init` is the only entry after the CRT.

Hello and `add_1x1024` bring-up are documented in [`../hello/README.md`](../hello/README.md)
and [`../README.md`](../README.md). The NR runtime is [`nr/README.md`](nr/README.md).
