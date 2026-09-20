//===- uart.h - NR UART public interface ----------------------------------===//
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
// Public UART API for the NH bare-metal runtime on NR FPGA.
// print_* and init_uart() are implemented in uart.c. MMIO helpers below
// (base 0x310b0000, TX at offset 0x20, fixed divisor 8, 8N1) are inline so
// the NR NH/RA runtime can share the same registers without a second copy
// of uart.c. freq and baud arguments to init_uart() are ignored.
//
//===----------------------------------------------------------------------===//

#ifndef __UART_H
#define __UART_H

#include <stdint.h>

// Called from _init() in bare_runtime.c before any print_*.
// freq and baud are kept for API compatibility; uart.c ignores them and
// programs the fixed divisor instead.
void init_uart(uint32_t freq, uint32_t baud);

// Write a NUL-terminated string. Does not append "\r\n"; callers supply it.
void print_uart(const char *text);

// Print value as exactly 8 uppercase hex digits, most significant nibble first.
// Despite the name, this is hexadecimal, not decimal.
void print_uart_int(uint32_t value);

// Print a 64-bit address as 16 hex digits: high 32 bits, then low 32 bits.
// Used by handle_trap() in bare_runtime.c for mcause / mepc / mtval.
void print_uart_addr(uint64_t value);

#define UART_BASE 0x310b0000UL
#define UART_REG(offset) (*(volatile uint32_t *)(UART_BASE + (offset)))

#define UART_RBR_THR_DLL UART_REG(0x00)
#define UART_IER_DLH UART_REG(0x04)
#define UART_FCR UART_REG(0x08)
#define UART_LCR UART_REG(0x0c)
#define UART_MCR UART_REG(0x10)
#define UART_LSR UART_REG(0x14)
#define UART_USR UART_REG(0x7c)
#define UART_THR UART_REG(0x20)

static inline void uart_init(void) {
  // Interrupts off. DLAB is still 0, so +0x04 is the interrupt-enable register.
  UART_IER_DLH = 0;

  // DLAB=1 selects the divisor latches. Low bits 11b select 8-bit data.
  UART_LCR = 0x83;

  // USR bit 0 is UART Busy. Wait until the line is idle before touching
  // DLL/DLH.
  while (UART_USR & 0x01)
    ;

  // DLAB=1: +0x04 is DLH, +0x00 is DLL.
  // Fixed divisor 0x0008 matches 14.7456 MHz / 115200.
  UART_IER_DLH = 0;
  UART_RBR_THR_DLL = 8;

  // DLAB=0, 8 data bits, no parity, 1 stop bit (8N1).
  UART_LCR = 0x03;

  // Enable FIFOs. Bit 0 only; do not set the flush bits.
  UART_FCR = 0x01;

  // Assert DTR (bit 0) and RTS (bit 1) so the link partner sees the port ready.
  UART_MCR = 0x03;
}

// Spin until LSR bit 5 (THR empty), then write the byte to the board TX
// register.
static inline void uart_putc(char c) {
  while ((UART_LSR & 0x20) == 0)
    ;
  UART_THR = c;
}

static inline int uart_rx_ready(void) { return (UART_LSR & 0x01) != 0; }

static inline char uart_getc(void) {
  while (!uart_rx_ready())
    ;
  return (char)(UART_RBR_THR_DLL & 0xffu);
}

#endif // __UART_H
