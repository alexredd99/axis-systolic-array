#include "platform.h"
#include "xparameters.h"
#include "xparameters_ps.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xtime_l.h"
#include "xil_io.h"
#include "xil_sleeptimer.h"
#include "xil_mmu.h"
#include "sleep.h"

#include <assert.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>

#define R 8
#define C 4
#define K 16
#define CONFIG_BASEADDR 0xA0000000
#define DIR

static inline void flush_cache(void *addr, uint32_t bytes) {
  Xil_DCacheFlushRange((INTPTR)addr, bytes);
}

#include "firmware.h"

int main()
{
  init_platform();

  // For baremetal, give physical address
  Memory_st *p_mem = (Memory_st *)MEM_BASEADDR;
  void *p_config = (void *)CONFIG_BASEADDR;
  // For linux, give virtual address
  // Memory_st *p_mem = (Memory_st *)mmap(NULL, sizeof(Memory_st), PROT_READ | PROT_WRITE, MAP_SHARED, dh, MEM_BASEADDR);
  // void *p_config = mmap(NULL, 4*16+N_BUNDLES*32, PROT_READ | PROT_WRITE, MAP_SHARED, dh, CONFIG_BASEADDR);

  xil_printf("Hello! Config:%p, Mem:%p\n", p_config, p_mem);

  for (int i = 0; i < BYTES; i++) {
    p_mem->inp_arr[i] = i;
  }
  flush_cache(p_mem->inp_arr, BYTES);
  
  run(p_mem, p_config);

  flush_cache(p_mem->out_arr, BYTES);
  usleep(0);
  for (int i = 0; i < BYTES; i++) {
    xil_printf("out_arr[%d]=%d\n", i, p_mem->out_arr[i]);
  }
  

  cleanup_platform();
  return 0;
}
