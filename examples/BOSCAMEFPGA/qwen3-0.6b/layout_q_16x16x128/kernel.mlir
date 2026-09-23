// Transpose Q from token-major projection view [S,16,128] to [16,S,128]
// (layout_q_16x16x128, f32). Part of the NR operator example suite; see
// ../../common/README.md for provenance.

#map = affine_map<(d0, d1, d2) -> (d1, d0, d2)>
#map1 = affine_map<(d0, d1, d2) -> (d0, d1, d2)>

module {
  func.func @kernel_layout_q_16x16x128(
      %x: memref<16x16x128xf32>,
      %out: memref<16x16x128xf32>) attributes {llvm.emit_c_interface} {
    linalg.generic {
        indexing_maps = [#map, #map1],
        iterator_types = ["parallel", "parallel", "parallel"]
      }
      ins(%x : memref<16x16x128xf32>)
      outs(%out : memref<16x16x128xf32>) {
    ^bb0(%v0: f32, %v1: f32):
      linalg.yield %v0 : f32
    }
    return
  }
}
