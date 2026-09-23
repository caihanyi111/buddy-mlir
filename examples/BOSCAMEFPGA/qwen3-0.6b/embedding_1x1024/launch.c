//===- launch.c - Board/host launcher for embedding_1x1024 ----------------===//
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
#ifdef HOST_TEST
typedef double oracle_float;
static float oracle_exp(float x) { return (float)exp((double)x); }
static float oracle_sqrt(float x) { return (float)sqrt((double)x); }
static float oracle_sin(float x) { return (float)sin((double)x); }
static float oracle_cos(float x) { return (float)cos((double)x); }
#else
typedef float oracle_float;
static float oracle_exp(float x) { return expf(x); }
static float oracle_sqrt(float x) { return sqrtf(x); }
static float oracle_sin(float x) { return sinf(x); }
static float oracle_cos(float x) { return cosf(x); }
#endif
static void compare(float actual, float expected, float atol, float rtol,
                    int *errors, float *maximum) {
  if (actual == expected)
    return;
  if (!__builtin_isfinite(actual) || !__builtin_isfinite(expected)) {
    ++*errors;
    *maximum = __builtin_inff();
    return;
  }
  if (!check_close(actual, expected, atol, rtol))
    ++*errors;
  float difference = actual - expected;
  if (difference < 0)
    difference = -difference;
  if (difference > *maximum)
    *maximum = difference;
}
extern void _mlir_ciface_kernel_embedding_1x1024(MemRef1 *, MemRef2 *,
                                                 MemRef2 *);
int launch(void) {
  int errors = 0;
  float maximum = 0;
  int64_t *ids = (int64_t *)workspace(0u);
  MemRef1 m_ids = make_1(ids, 1);
  float *out = (float *)workspace(64u);
  MemRef2 m_out = make_2(out, 1, 1024);
  float *weight = (float *)workspace(4160u);
  MemRef2 m_weight = make_2(weight, 151936, 1024);
  for (int s = 0; s < 1; ++s) {
    ids[s] = (s % 4 == 0) ? 151935 : ((s * 997 + 3) % 151936);
    for (int k = 0; k < 1024; ++k) {
      weight[ids[s] * 1024 + k] =
          (float)((ids[s] + k * 3) % 97 - 48) * 0.03125f;
      out[s * 1024 + k] = 9999;
    }
  }
  _mlir_ciface_kernel_embedding_1x1024(&m_ids, &m_out, &m_weight);
  for (int s = 0; s < 1; ++s)
    for (int k = 0; k < 1024; ++k) {
      float expected = (float)((ids[s] + k * 3) % 97 - 48) * 0.03125f;
      compare(out[s * 1024 + k], expected, 0, 0, &errors, &maximum);
    }
  return print_check("embedding_1x1024", errors, maximum);
}
