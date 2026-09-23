// Gather full-vocabulary embedding rows [151936,1024]; tied lm_head shares this
// weight semantically (embedding_1x1024, f32). Part of the NR operator example
// suite; see ../../common/README.md for provenance.

#map = affine_map<(d0, d1) -> (d0)>
#map1 = affine_map<(d0, d1) -> (d0, d1)>

module {
  func.func @kernel_embedding_1x1024(
      %ids: memref<1xi64>,
      %out: memref<1x1024xf32>,
      %weight: memref<151936x1024xf32>) attributes {llvm.emit_c_interface} {
    linalg.generic {
        indexing_maps = [#map, #map1],
        iterator_types = ["parallel", "parallel"]
      }
      ins(%ids : memref<1xi64>)
      outs(%out : memref<1x1024xf32>) {
    ^bb0(%v0: i64, %v1: f32):
      %feature = linalg.index 1 : index
      %token = arith.index_cast %v0 : i64 to index
      %value = memref.load %weight[%token, %feature] : memref<151936x1024xf32>
      linalg.yield %value : f32
    }
    return
  }
}
