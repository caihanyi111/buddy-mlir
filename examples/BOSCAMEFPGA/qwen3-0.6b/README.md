# qwen3-0.6b NR operator suite

Linalg operators for the NR FPGA. Each operator directory has `kernel.mlir`
and `launch.c`, builds through [`common.mk`](common.mk), and links
[`../common/nr`](../common/nr/README.md) (not `../common/runtime`).

**This table is the only operator inventory.** When you add a new operator,
add one row here (and the directory); do not update the parent
[`../README.md`](../README.md) Examples list.

| Operator | Status | Notes |
| --- | --- | --- |
| [`add_1x1024/`](add_1x1024/) | Working | f32 elementwise add |
| [`add_16x1024/`](add_16x1024/) | Working | f32 elementwise add |
| [`mul_1x3072/`](mul_1x3072/) | Working | f32 elementwise mul |
| [`mul_16x3072/`](mul_16x3072/) | Working | f32 elementwise mul |
| [`silu_1x3072/`](silu_1x3072/) | Working | f32 SiLU |
| [`silu_16x3072/`](silu_16x3072/) | Working | f32 SiLU |
| [`rmsnorm_1x1024/`](rmsnorm_1x1024/) | Working | f32 RMSNorm |
| [`rmsnorm_16x1024/`](rmsnorm_16x1024/) | Working | f32 RMSNorm |
| [`rmsnorm_8x128/`](rmsnorm_8x128/) | Working | f32 RMSNorm (per-head) |
| [`rmsnorm_16x128/`](rmsnorm_16x128/) | Working | f32 RMSNorm (per-head) |
| [`rmsnorm_128x128/`](rmsnorm_128x128/) | Working | f32 RMSNorm (per-head) |
| [`rmsnorm_256x128/`](rmsnorm_256x128/) | Working | f32 RMSNorm (per-head) |
| [`softmax_16x16x16/`](softmax_16x16x16/) | Working | f32 softmax |
| [`softmax_16x1x17/`](softmax_16x1x17/) | Working | f32 softmax |
| [`rope_1x8x128/`](rope_1x8x128/) | Working | f32 RoPE |
| [`rope_1x16x128/`](rope_1x16x128/) | Working | f32 RoPE |
| [`rope_16x8x128/`](rope_16x8x128/) | Working | f32 RoPE |
| [`rope_16x16x128/`](rope_16x16x128/) | Working | f32 RoPE |
| [`embedding_1x1024/`](embedding_1x1024/) | Working | f32 embedding gather |
| [`embedding_16x1024/`](embedding_16x1024/) | Working | f32 embedding gather |
| [`layout_q_1x16x128/`](layout_q_1x16x128/) | Working | Q layout transpose |
| [`layout_q_16x16x128/`](layout_q_16x16x128/) | Working | Q layout transpose |
| [`layout_k_16x16x128/`](layout_k_16x16x128/) | Working | K layout transpose |
| [`layout_k_16x17x128/`](layout_k_16x17x128/) | Working | K layout transpose |
| [`layout_k_16x512x128/`](layout_k_16x512x128/) | Working | K layout transpose |
| [`layout_context_8x1x128/`](layout_context_8x1x128/) | Working | context layout |
| [`layout_context_8x16x128/`](layout_context_8x16x128/) | Working | context layout |
| [`layout_context_16x1x128/`](layout_context_16x1x128/) | Working | context layout |
| [`layout_context_16x16x128/`](layout_context_16x16x128/) | Working | context layout |
| [`kv_cache_update_1x8x128/`](kv_cache_update_1x8x128/) | Working | KV cache update |
| [`kv_cache_update_16x8x128/`](kv_cache_update_16x8x128/) | Working | KV cache update |
| [`gqa_repeat_8x16x128_to_16x16x128/`](gqa_repeat_8x16x128_to_16x16x128/) | Working | GQA repeat_kv |
| [`gqa_repeat_8x17x128_to_16x17x128/`](gqa_repeat_8x17x128_to_16x17x128/) | Working | GQA repeat_kv |
| [`attention_scale_mask_16x1x17/`](attention_scale_mask_16x1x17/) | Working | attention scale+mask |
| [`attention_scale_mask_16x16x16/`](attention_scale_mask_16x16x16/) | Working | attention scale+mask |
| [`quantize_1x1024/`](quantize_1x1024/) | Working | per-token f32 to i8 |
| [`quantize_16x1024/`](quantize_16x1024/) | Working | per-token f32 to i8 |
| [`quantize_1x2048/`](quantize_1x2048/) | Working | per-token f32 to i8 |
| [`quantize_16x2048/`](quantize_16x2048/) | Working | per-token f32 to i8 |
| [`quantize_1x3072/`](quantize_1x3072/) | Working | per-token f32 to i8 |
| [`quantize_16x3072/`](quantize_16x3072/) | Working | per-token f32 to i8 |
| [`dequantize_1x1024/`](dequantize_1x1024/) | Working | i32 to f32 |
| [`dequantize_16x1024/`](dequantize_16x1024/) | Working | i32 to f32 |
| [`dequantize_1x2048/`](dequantize_1x2048/) | Working | i32 to f32 |
| [`dequantize_16x2048/`](dequantize_16x2048/) | Working | i32 to f32 |
| [`dequantize_1x3072/`](dequantize_1x3072/) | Working | i32 to f32 |
| [`dequantize_16x3072/`](dequantize_16x3072/) | Working | i32 to f32 |
| [`dequantize_1x151936/`](dequantize_1x151936/) | Working | i32 to f32 |
| [`embedding_w8a8_1x1024/`](embedding_w8a8_1x1024/) | Working | int8 embedding gather |
| [`embedding_w8a8_16x1024/`](embedding_w8a8_16x1024/) | Working | int8 embedding gather |

## Build / run pattern

From the repository root (needs `buddy-opt` / `buddy-translate` in
`build/bin`, or set `BUDDY_BIN`):

```bash
make -C examples/BOSCAMEFPGA/qwen3-0.6b/<op> all check
```

`all` writes `<op>/build/<op>.bin`. `check` is a **host oracle** only; it
does not replace a board run.

```bash
export FPGA_SSH_HOST=<ssh-alias-or-host>
export FPGA_REMOTE_DIR=<uvhs-workdir>

examples/BOSCAMEFPGA/fpga_run.sh \
  examples/BOSCAMEFPGA/qwen3-0.6b/<op>/build/<op>.bin \
  --fpga=<N> --capture-seconds=900
```

Success on UART: `verify <op>: PASS`. Shared launcher notes:
[`../README.md`](../README.md), [`../tools/README.md`](../tools/README.md).

## Pipeline (every operator)

Via `common.mk`:

1. `buddy-opt --lower-linalg-to-boscame=target=nr-fpga` stamps the NR contract
2. Further lowering depends on the kernel (elementwise → `convert-linalg-to-loops`;
   matmul / AME paths differ — see each directory’s `kernel.mlir`)
3. `tools/ame_to_word.py` → `restrict_fpga_assembly.py` → link with `nr.ld`
4. `tools/check_nr_elf.py` audits the linked ELF

Do not link `common/runtime` into an operator image. Shared helpers:
[`support.h`](support.h) / [`support.c`](support.c). Details:
[`../common/nr/README.md`](../common/nr/README.md).

## Layout

```text
qwen3-0.6b/
├── common.mk              # Shared operator build
├── support.h / support.c  # MemRef / workspace / print_check
├── tools/
│   ├── host_main.c        # Host `main` for make check
│   ├── build_suite.py     # Multi-operator image packing
│   └── vectorize_nr.py    # Optional matmul vectorization driver
└── <op>/                  # One directory per operator (see table above)
    ├── makefile           # include ../common.mk
    ├── kernel.mlir
    ├── launch.c
    └── metadata.json
```

## See also

- Tree overview: [`../README.md`](../README.md)
- NR NH/RA runtime: [`../common/nr/README.md`](../common/nr/README.md)
- Encode / restrict / ELF audit: [`../tools/README.md`](../tools/README.md)
