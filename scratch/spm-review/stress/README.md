# Planner 压力用例：逼出「两缺口之后」的剩余问题

针对：

1. **Emit 守约**（Plan 驻留窗）— Fill→Load→Reduce 同缓冲应留在 SPM
2. **部分更新 / inplace 安全** — 前缀覆盖后 inplace 减 mean，单一 root
3. **可重算常量勿物化** — Fill 0/1 不应走完整 SPM↔stack 生命周期
4. **bank / Must-May-Spill** — 多块超容量；AME 后 Must 接 RVV
5. **REG 估错 → 二次 spill** — 64KiB 向量误当 REG 常驻

默认只喂 **buffer-form MLIR → `--linalg-to-boscame`**。

## 一键跑

```bash
source ~/miniconda3/etc/profile.d/conda.sh && conda activate boscame
export REPO=~/work/buddy-mlir-for-fpga
export BUDDY_OPT=$REPO/build-migrate/bin/buddy-opt
cd $REPO/scratch/spm-review/stress
chmod +x run_stress.sh
./run_stress.sh
```

## 用例 ↔ 问题 ↔ 算子

| 名 | 逼什么 | 关键算子链 | 基线 |
|----|--------|------------|------|
| `00_layernorm_bufferized` | Emit + 常量（真 LN） | fill / copy / generic / reduce | **FAIL** dma≈37 |
| `01_emit_window` | Emit 守约 | `linalg.fill` → `memref.copy` → `linalg.reduce` | **FAIL** SPM↔stack bounce |
| `02_partial_inplace` | 部分写/inplace | fill → 前缀 copy → inplace `generic` | **FAIL** 多 root/DMA |
| `03_const_materialize` | 常量勿物化 | fill 0/1 → 前缀 copy → add | **FAIL** dma=5 |
| `04_bank_spill` | bank / Spill | 8×64KiB 同时活跃 + 两级 add | **PASS**（capacity-spills>0） |
| `05_must_ame_rvv` | Must AME→RVV | `linalg.matmul` → broadcast `addi` | **PASS**（tile+spm，Bias 列广播） |
| `06_reg_pressure` | REG 二次 spill | 64KiB `mulf` | PASS（尚无 REG 字段） |

`FAIL` = 问题被逼出或尚未修好。产物：`out/<id>/{kernel.boscame.mlir,plan-report.txt,summary.txt}`。

## 判读要点

- **Emit**：`residency=operation-local` 连片 + Fill 后 `dma` SPM→`alloca` 再拷回 → 窗未守。
- **部分写**：同一 `%buf` 应贯穿；若 fill/mean/inplace 各有一套 `spm.view`+DMA → 不安全。
- **常量**：理想是 mask/`other` 在 REG 重算；出现对 0/1 整块 `vector.store`+`dma` 4096B → 物化过度。
- **bank**：超容量应 `capacity-spills>0` 并成功编译（Spill 到 DDR），不应再硬报 `capacity exceeded`。
- **Must**：`tile.mma` 后 elementwise 应有 ACC→SPM→RVV；Bias 列广播 `(d0,d1)->(d1)` 应能 `vector.load` 后 `addi`。
- **REG**：plan-report 应能拒绝「整 64KiB 进 REG」；否则看二次 `alloca`/`dma` 气味。
