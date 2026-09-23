// Dequantize i32 with per-row and per-column scales (dequantize_1x1024, i32 to
// f32). Part of the NR operator example suite; see ../../common/README.md for
// provenance.

#map = affine_map<(i, j) -> (i, j)>
#map1 = affine_map<(i, j) -> (i)>
#map2 = affine_map<(i, j) -> (j)>

module {
  func.func @kernel_dequantize_1x1024(
      %x: memref<1x1024xi32>,
      %row: memref<1xf32>,
      %col: memref<1024xf32>,
      %y: memref<1x1024xf32>) attributes {llvm.emit_c_interface} {
    linalg.generic {
        indexing_maps = [#map, #map1, #map2, #map],
        iterator_types = ["parallel", "parallel"]
      }
      ins(%x, %row, %col : memref<1x1024xi32>, memref<1xf32>, memref<1024xf32>)
      outs(%y : memref<1x1024xf32>) {
    ^bb0(%xv: i32, %rs: f32, %cs: f32, %unused: f32):
      %f = arith.sitofp %xv : i32 to f32
      %a = arith.mulf %f, %rs : f32
      %b = arith.mulf %a, %cs : f32
      linalg.yield %b : f32
    }
    return
  }
}
