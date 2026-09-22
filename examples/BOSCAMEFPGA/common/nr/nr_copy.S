#===- nr_copy.S - Aligned RVV memcpy for NR -------------------------------===#
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#===----------------------------------------------------------------------===#
#
# void nr_copy_bytes(void *dst, const void *src, size_t bytes);
#
# Non-overlapping copy used by the NR operator runtime. When dst and src are
# both 4-byte aligned, copies with RVV e32/m1 (at most 16 lanes per issue) and
# places fence rw,rw on both sides of every vector memory op (NR contract).
# Unaligned pointers and the final 0..3 bytes use scalar byte loads/stores.
# Clobbers v8, vl, and vtype; callers must not retain vector state across the
# call.
#
# Adapted from ModelZoo runtime/asm/qwen35_rvv_copy.S (commit
# 8815b74fb6d3cd6288c4d99ac6fd7c5d041a7cc3). See README.md for provenance.
#
#===----------------------------------------------------------------------===#

  .text
  .balign 4
  .globl nr_copy_bytes
  .type nr_copy_bytes,@function
nr_copy_bytes:
  # a0=dst, a1=src, a2=bytes
  beqz a2, .Ldone
  # Fall back to bytes if either pointer is not 4-byte aligned.
  or t1, a0, a1
  andi t1, t1, 3
  bnez t1, .Lbytes
  andi a3, a2, 3          # leftover bytes after word copies
  srli a2, a2, 2          # remaining 32-bit words
  beqz a2, .Ltail
.Lwords:
  li t0, 16               # VL max for e32,m1 on this board path
  bgeu a2, t0, .Lsetvl
  mv t0, a2
.Lsetvl:
  vsetvli t0, t0, e32, m1, ta, ma
  fence rw, rw
  vle32.v v8, (a1)
  fence rw, rw
  vse32.v v8, (a0)
  fence rw, rw
  sub a2, a2, t0
  slli t0, t0, 2
  add a0, a0, t0
  add a1, a1, t0
  bnez a2, .Lwords
.Ltail:
  mv a2, a3
  beqz a2, .Ldone
.Lbytes:
  lbu t0, 0(a1)
  sb t0, 0(a0)
  addi a0, a0, 1
  addi a1, a1, 1
  addi a2, a2, -1
  bnez a2, .Lbytes
  fence rw, rw
.Ldone:
  ret
  .size nr_copy_bytes, .-nr_copy_bytes
  .section .note.GNU-stack,"",@progbits
