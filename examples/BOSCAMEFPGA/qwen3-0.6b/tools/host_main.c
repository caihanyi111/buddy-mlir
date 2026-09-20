//===- host_main.c - Host entry for make check ----------------------------===//
//
// Provides main() so the host oracle can call launch(). Board images use
// common/nr/crt.S instead. Part of the NR operator example suite; see
// ../../common/README.md for provenance.
//
//===----------------------------------------------------------------------===//

int launch(void);
int main(void) { return launch(); }
