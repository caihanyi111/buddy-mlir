#!/usr/bin/env bash
# Run Planner stress MLIR cases and classify PASS/FAIL/ERROR.
# FAIL = anti-pattern still present (problem exposed / not fixed yet).
set -u
ROOT=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$ROOT/../../.." && pwd)
OPT=${BUDDY_OPT:-}
if [[ -z "${OPT}" || ! -x "${OPT}" ]]; then
  for cand in "$REPO/build-migrate/bin/buddy-opt" "$REPO/build/bin/buddy-opt"; do
    [[ -x "$cand" ]] && OPT=$cand && break
  done
fi
if [[ ! -x "${OPT:-}" ]]; then
  echo "error: set BUDDY_OPT to buddy-opt with --linalg-to-boscame" >&2
  exit 1
fi

OUT="$ROOT/out"
mkdir -p "$OUT"
echo "Using OPT=$OPT"
echo "Results under $OUT"
echo

count_re() {
  local file=$1 pat=$2
  if [[ ! -f "$file" ]]; then echo 0; return; fi
  local n
  n=$(grep -cE "$pat" "$file" 2>/dev/null || true)
  echo "${n:-0}"
}

# Heuristic: DMA between an alloca-like memref and SPM in either direction.
# High counts after Fill/before Reduce indicate emit window violations.
count_spm_stack_dma() {
  local mlir=$1
  # Lines that mention both spm and a non-spm memref endpoint in dma.start
  grep -E 'bosc_ame\.dma\.start' "$mlir" 2>/dev/null \
    | grep -E 'spm' \
    | grep -cvE 'memref<\*x|memref<\?x' \
    || true
}

run_case() {
  local id=$1
  local src=$ROOT/mlir/${id}.mlir
  local dir=$OUT/$id
  mkdir -p "$dir"
  local policy=spm-dma
  local enable="enable-spm-dma=true"
  if [[ "$id" == "05_must_ame_rvv" ]]; then
    policy=direct-ddr
    enable="enable-spm-dma=true"
  fi

  echo "======== $id ========"
  local flags="store-policy=${policy} ${enable} plan-report=true"
  set +e
  "$OPT" "$src" --linalg-to-boscame="$flags" \
    -o "$dir/kernel.boscame.mlir" 2>"$dir/plan-report.txt"
  local rc=$?
  set -e

  {
    echo "id=$id exit=$rc policy=$policy"
    echo -n "spm.view="; count_re "$dir/kernel.boscame.mlir" 'bosc_ame\.spm\.view'
    echo -n "dma="; count_re "$dir/kernel.boscame.mlir" 'bosc_ame\.dma\.(start|wait)'
    echo -n "tile="; count_re "$dir/kernel.boscame.mlir" 'bosc_ame\.tile\.'
    echo -n "direct_ddr="; count_re "$dir/kernel.boscame.mlir" 'direct_ddr'
    echo -n "vector="; count_re "$dir/kernel.boscame.mlir" 'vector\.(load|store)'
    echo -n "alloca="; count_re "$dir/kernel.boscame.mlir" 'memref\.alloca'
    grep -E 'high-water|capacity|residency|limits:|ame-input|direct-A' \
      "$dir/plan-report.txt" 2>/dev/null | head -20 || true
  } | tee "$dir/summary.txt"

  local verdict=ERROR
  local note=""

  case "$id" in
    00_layernorm_bufferized|01_emit_window)
      if [[ $rc -ne 0 ]]; then
        verdict=FAIL; note="lower failed (also exposes gap)"
      else
        local dma alloca bounce
        dma=$(count_re "$dir/kernel.boscame.mlir" 'bosc_ame\.dma\.start')
        alloca=$(count_re "$dir/kernel.boscame.mlir" 'memref\.alloca')
        # Smoking gun: Fill on SPM then DMA SPM↔stack before consumer.
        bounce=0
        if grep -qE 'vector\.store.*#bosc_ame\.spm' "$dir/kernel.boscame.mlir" \
          && grep -qE 'dma\.start.*#bosc_ame\.spm.*>.*memref<[^#]+>' "$dir/kernel.boscame.mlir"; then
          bounce=1
        fi
        local lim=6
        [[ "$id" == "00_layernorm_bufferized" ]] && lim=12
        if [[ "$bounce" -eq 1 || "$dma" -gt "$lim" ]]; then
          verdict=FAIL
          note="dma.start=$dma alloca=$alloca bounce=$bounce (Fill/Load/Reduce SPM↔stack)"
        else
          verdict=PASS
          note="dma.start=$dma"
        fi
      fi
      ;;
    02_partial_inplace)
      if [[ $rc -ne 0 ]]; then
        verdict=FAIL; note="lower failed on partial/inplace"
      else
        local dma spm
        dma=$(count_re "$dir/kernel.boscame.mlir" 'bosc_ame\.dma\.start')
        spm=$(count_re "$dir/kernel.boscame.mlir" 'bosc_ame\.spm\.view')
        # Ideal: one root stays on SPM across fill/partial-copy/inplace (dma≈1–2).
        # Anti-pattern: fill→DMA stack→reload + separate mean buffer lifecycle.
        if [[ "$dma" -gt 2 || "$spm" -gt 2 ]]; then
          verdict=FAIL
          note="dma.start=$dma spm.view=$spm; partial/inplace split across temps/banks"
        else
          verdict=PASS
          note="dma.start=$dma (manual: confirm single root in IR)"
        fi
      fi
      ;;
    03_const_materialize)
      if [[ $rc -ne 0 ]]; then
        verdict=FAIL; note="lower failed"
      else
        # Count DMA whose byte size is 4096 (1024*f32) — often the padding fill traffic
        local big
        big=$(grep -cE 'dma\.start.*, %c4096|dma\.start.*, 4096' "$dir/kernel.boscame.mlir" 2>/dev/null || echo 0)
        # Also flag many fill→spm vector stores of constants before any DDR copy
        local dma; dma=$(count_re "$dir/kernel.boscame.mlir" 'bosc_ame\.dma\.start')
        if [[ "$dma" -gt 4 ]]; then
          verdict=FAIL
          note="dma.start=$dma; suspect const 0/1 buffers got full SPM lifecycles"
        else
          verdict=PASS
          note="dma.start=$dma"
        fi
      fi
      ;;
    04_bank_spill)
      if [[ $rc -ne 0 ]]; then
        if grep -qiE 'capacity exceeded|workspace capacity' "$dir/plan-report.txt"; then
          verdict=FAIL
          note="capacity hard-fail (Spill fallback missing)"
        else
          verdict=FAIL
          note="lower failed: $(head -1 "$dir/plan-report.txt")"
        fi
      else
        local spills
        spills=$(grep -oE 'capacity-spills=[0-9]+' "$dir/plan-report.txt" | head -1 || true)
        if [[ -z "$spills" || "$spills" == "capacity-spills=0" ]]; then
          verdict=FAIL
          note="compiled but no capacity-spills recorded (expected Spill)"
        else
          verdict=PASS
          note="graceful Spill: $spills"
        fi
      fi
      ;;
    05_must_ame_rvv)
      if [[ $rc -ne 0 ]]; then
        verdict=FAIL
        note="Must path failed to lower: $(grep -E 'error:' "$dir/plan-report.txt" | head -1)"
      else
        local tile spm
        tile=$(count_re "$dir/kernel.boscame.mlir" 'bosc_ame\.tile\.mma')
        spm=$(count_re "$dir/kernel.boscame.mlir" 'bosc_ame\.spm\.view')
        if [[ "$tile" -ge 1 && "$spm" -eq 0 ]]; then
          # tile only + elementwise: if bias add has no SPM bridge, Must may be violated
          if grep -qE 'vector\.(load|store)|linalg\.generic|arith\.addi' "$dir/kernel.boscame.mlir"; then
            verdict=FAIL
            note="mma present but spm.view=0 while post-add exists — check Must ACC→SPM→RVV"
          else
            verdict=PASS
            note="unexpected shape"
          fi
        elif [[ "$tile" -ge 1 && "$spm" -ge 1 ]]; then
          verdict=PASS
          note="tile=$tile spm=$spm (Must bridge may exist; inspect IR)"
        else
          verdict=FAIL
          note="tile=$tile spm=$spm"
        fi
      fi
      ;;
    06_reg_pressure)
      if [[ $rc -ne 0 ]]; then
        verdict=FAIL; note="lower failed"
      else
        local dma spm
        dma=$(count_re "$dir/kernel.boscame.mlir" 'bosc_ame\.dma\.start')
        spm=$(count_re "$dir/kernel.boscame.mlir" 'bosc_ame\.spm\.view')
        # After REG model: plan should NOT claim full REG residency for 64KiB.
        if grep -qiE 'register|reg-resid|rvv.*unknown' "$dir/plan-report.txt"; then
          note="see plan-report REG fields; dma=$dma spm=$spm"
        else
          note="no REG fields in plan-report yet (gap#1); dma=$dma spm=$spm"
        fi
        # Secondary spill smell: many alloca + dma for one simple mul
        local alloca
        alloca=$(count_re "$dir/kernel.boscame.mlir" 'memref\.alloca')
        if [[ "$dma" -gt 6 || "$alloca" -gt 3 ]]; then
          verdict=FAIL
          note="possible bounce/spill smell: dma=$dma alloca=$alloca ($note)"
        else
          verdict=PASS
          note="$note"
        fi
      fi
      ;;
    *)
      verdict=ERROR; note="unknown case"
      ;;
  esac

  echo "VERDICT=$verdict  $note" | tee -a "$dir/summary.txt"
  echo
  echo "$id $verdict" >>"$OUT/results.txt"
}

# Optional: real LayerNorm bufferized (best E2E for emit window + const)
LN_BUF=$REPO/scratch/spm-review/out/layernorm197/spm-dma/kernel.bufferized.mlir
if [[ -f "$LN_BUF" ]]; then
  cp -f "$LN_BUF" "$ROOT/mlir/00_layernorm_bufferized.mlir"
fi

: >"$OUT/results.txt"
for id in \
  00_layernorm_bufferized \
  01_emit_window \
  02_partial_inplace \
  03_const_materialize \
  04_bank_spill \
  05_must_ame_rvv \
  06_reg_pressure
do
  if [[ ! -f "$ROOT/mlir/${id}.mlir" ]]; then
    echo "======== $id ======== SKIP (missing mlir)"
    echo "$id SKIP" >>"$OUT/results.txt"
    echo
    continue
  fi
  run_case "$id"
done

echo "======== SUMMARY ========"
column -t "$OUT/results.txt" 2>/dev/null || cat "$OUT/results.txt"
echo
echo "FAIL = problem exposed (or not yet fixed). Inspect out/<id>/kernel.boscame.mlir"
echo "Also run LayerNorm E2E:"
echo "  $REPO/examples/FPGA-BOSCAME/tools/run_one.sh layernorm197 \\"
echo "    $REPO/examples/FPGA-BOSCAME/layernorm_197x768/build/layernorm_197x768/kernel.ttir spm-dma"
