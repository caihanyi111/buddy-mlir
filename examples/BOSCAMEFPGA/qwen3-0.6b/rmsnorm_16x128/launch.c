//===- launch.c - Board/host launcher for rmsnorm_16x128 ------------------===//
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
extern void _mlir_ciface_kernel_rmsnorm_16x128(MemRef2 *, MemRef1 *, MemRef1 *,
                                               MemRef2 *);
int launch(void) {
  int errors = 0;
  float maximum = 0;
  float *x = (float *)workspace(0u);
  MemRef2 m_x = make_2(x, 16, 128);
  float *weight = (float *)workspace(8192u);
  MemRef1 m_weight = make_1(weight, 128);
  float *sums = (float *)workspace(8704u);
  MemRef1 m_sums = make_1(sums, 16);
  float *out = (float *)workspace(8768u);
  MemRef2 m_out = make_2(out, 16, 128);
  for (int i = 0; i < 2048; ++i) {
    x[i] = (float)((i * 7) % 37 - 18) * 0.0625f;
    if (i < 128)
      x[i] *= 1e-5f;
    else if (i < 256)
      x[i] = 0;
    out[i] = 9999;
  }
  for (int i = 0; i < 128; ++i)
    weight[i] = 0.75f + (float)(i % 7) * 0.0625f;
  _mlir_ciface_kernel_rmsnorm_16x128(&m_x, &m_weight, &m_sums, &m_out);
  for (int r = 0; r < 16; ++r) {
    oracle_float sum = 0;
    for (int k = 0; k < 128; ++k) {
      oracle_float value = x[r * 128 + k];
      sum += value * value;
    }
    float denominator = oracle_sqrt((float)(sum / 128) + 1e-6f);
    for (int k = 0; k < 128; ++k) {
      int i = r * 128 + k;
      compare(out[i], x[i] / denominator * weight[k], 3e-6f, 5e-5f, &errors,
              &maximum);
    }
  }
  return print_check("rmsnorm_16x128", errors, maximum);
}
