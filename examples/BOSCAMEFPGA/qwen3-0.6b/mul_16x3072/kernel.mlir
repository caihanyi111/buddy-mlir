// SwiGLU activation/product (mul_16x3072, f32). Part of the NR operator example
// suite; see ../../common/README.md for provenance.

#map = affine_map<(d0, d1) -> (d0, d1)>

module {
  func.func @kernel_mul_16x3072(
      %x: memref<16x3072xf32>,
      %y: memref<16x3072xf32>,
      %out: memref<16x3072xf32>) attributes {llvm.emit_c_interface} {
    linalg.generic {
        indexing_maps = [#map, #map, #map],
        iterator_types = ["parallel", "parallel"]
      }
      ins(%x, %y : memref<16x3072xf32>, memref<16x3072xf32>)
      outs(%out : memref<16x3072xf32>) {
    ^bb0(%v0: f32, %v1: f32, %v2: f32):
      %r = arith.mulf %v0, %v1 : f32
      linalg.yield %r : f32
    }
    return
  }
}
