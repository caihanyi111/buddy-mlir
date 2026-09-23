// Dequantize i32 with per-row and per-column scales (dequantize_16x2048, i32 to
// f32). Part of the NR operator example suite; see ../../common/README.md for
// provenance.

#map = affine_map<(i, j) -> (i, j)>
#map1 = affine_map<(i, j) -> (i)>
#map2 = affine_map<(i, j) -> (j)>

module {
  func.func @kernel_dequantize_16x2048(
      %x: memref<16x2048xi32>,
      %row: memref<16xf32>,
      %col: memref<2048xf32>,
      %y: memref<16x2048xf32>) attributes {llvm.emit_c_interface} {
    linalg.generic {
        indexing_maps = [#map, #map1, #map2, #map],
        iterator_types = ["parallel", "parallel"]
      }
      ins(%x, %row, %col : memref<16x2048xi32>, memref<16xf32>, memref<2048xf32>)
      outs(%y : memref<16x2048xf32>) {
    ^bb0(%xv: i32, %rs: f32, %cs: f32, %unused: f32):
      %f = arith.sitofp %xv : i32 to f32
      %a = arith.mulf %f, %rs : f32
      %b = arith.mulf %a, %cs : f32
      linalg.yield %b : f32
    }
    return
  }
}
