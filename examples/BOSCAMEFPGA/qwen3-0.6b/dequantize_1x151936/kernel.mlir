// Dequantize i32 with per-row and per-column scales (dequantize_1x151936, i32 to
// f32). Part of the NR operator example suite; see ../../common/README.md for
// provenance.

#map = affine_map<(i, j) -> (i, j)>
#map1 = affine_map<(i, j) -> (i)>
#map2 = affine_map<(i, j) -> (j)>

module {
  func.func @kernel_dequantize_1x151936(
      %x: memref<1x151936xi32>,
      %row: memref<1xf32>,
      %col: memref<151936xf32>,
      %y: memref<1x151936xf32>) attributes {llvm.emit_c_interface} {
    linalg.generic {
        indexing_maps = [#map, #map1, #map2, #map],
        iterator_types = ["parallel", "parallel"]
      }
      ins(%x, %row, %col : memref<1x151936xi32>, memref<1xf32>, memref<151936xf32>)
      outs(%y : memref<1x151936xf32>) {
    ^bb0(%xv: i32, %rs: f32, %cs: f32, %unused: f32):
      %f = arith.sitofp %xv : i32 to f32
      %a = arith.mulf %f, %rs : f32
      %b = arith.mulf %a, %cs : f32
      linalg.yield %b : f32
    }
    return
  }
}
