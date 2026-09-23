// Residual connection (add_1x1024, f32). Part of the NR operator example suite;
// see ../../common/README.md for provenance.

#map = affine_map<(d0, d1) -> (d0, d1)>

module {
  func.func @kernel_add_1x1024(
      %x: memref<1x1024xf32>,
      %y: memref<1x1024xf32>,
      %out: memref<1x1024xf32>) attributes {llvm.emit_c_interface} {
    linalg.generic {
        indexing_maps = [#map, #map, #map],
        iterator_types = ["parallel", "parallel"]
      }
      ins(%x, %y : memref<1x1024xf32>, memref<1x1024xf32>)
      outs(%out : memref<1x1024xf32>) {
    ^bb0(%v0: f32, %v1: f32, %v2: f32):
      %r = arith.addf %v0, %v1 : f32
      linalg.yield %r : f32
    }
    return
  }
}
