//===- launch.c - Board/host launcher for dequantize_1x2048 ---------------===//
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//===----------------------------------------------------------------------===//
//
// Fills workspace, calls the MLIR C iface, and checks against a C oracle.
// Linked for both HOST_TEST (make check) and the NR board image.
//
//===----------------------------------------------------------------------===//

#include "support.h"
#define M 1
#define N 2048
extern void _mlir_ciface_kernel_dequantize_1x2048(MemRef2 *, MemRef1 *,
                                                  MemRef1 *, MemRef2 *);
int launch(void) {
  int32_t *x = workspace(0);
  float *r = workspace(M * N * 4), *s = workspace(M * N * 4 + 64),
        *y = workspace(M * N * 4 + 64 + N * 4);
  for (int i = 0; i < M; i++)
    r[i] = (i + 1) * 0.00390625f;
  for (int j = 0; j < N; j++)
    s[j] = (j % 31 + 1) * 0.001953125f;
  for (int i = 0; i < M * N; i++)
    x[i] = (i % 1023 - 511) * 7919;
  MemRef2 X = make_2(x, M, N), Y = make_2(y, M, N);
  MemRef1 R = make_1(r, M), S = make_1(s, N);
  _mlir_ciface_kernel_dequantize_1x2048(&X, &R, &S, &Y);
  unsigned errors = 0;
  float max_error = 0;
  for (int i = 0; i < M; i++)
    for (int j = 0; j < N; j++) {
      float want = (float)x[i * N + j] * r[i] * s[j], d = y[i * N + j] - want;
      if (d < 0)
        d = -d;
      if (d > max_error)
        max_error = d;
      if (!check_close(y[i * N + j], want, 1e-6f, 1e-6f))
        errors++;
    }
  return print_check("dequantize_1x2048", errors, max_error);
}
