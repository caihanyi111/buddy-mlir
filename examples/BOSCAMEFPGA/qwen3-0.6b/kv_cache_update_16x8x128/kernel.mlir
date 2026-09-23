// Append projected/rotated K or projected V from [S,8,128] into [8,32,128]
// cache; preserve untouched entries (kv_cache_update_16x8x128, f32). Part of the
// NR operator example suite; see ../../common/README.md for provenance.

#map = affine_map<(d0, d1, d2) -> (d0, d1, d2)>

module {
  func.func @kernel_kv_cache_update_16x8x128(
      %x: memref<16x8x128xf32>,
      %cache: memref<8x32x128xf32>) attributes {llvm.emit_c_interface} {
    %past = arith.constant 0 : index
    linalg.generic {
        indexing_maps = [#map],
        iterator_types = ["parallel", "parallel", "parallel"]
      }
      outs(%x : memref<16x8x128xf32>) {
    ^bb0(%v0: f32):
      %s = linalg.index 0 : index
      %h = linalg.index 1 : index
      %d = linalg.index 2 : index
      %position = arith.addi %s, %past : index
      memref.store %v0, %cache[%h, %position, %d] : memref<8x32x128xf32>
      linalg.yield %v0 : f32
    }
    return
  }
}
