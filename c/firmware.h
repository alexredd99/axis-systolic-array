// DIR are macros defined through compiler options, or outside

// Assume k,x,a are 8 bit, y is 32 bit
#include "params.h"

#define NK K*C
#define NX R*K
#define NY R*C
#define NA NY

typedef struct {
  signed char k [K][C];
  signed char x [K][R];
  signed int  a [C][R];
  signed int  y [C][R];
} Memory_st;

#define MEM_BASEADDR    0x20000000
#define CONFIG_BASEADDR 0xA0000000
#define A_START         0x0
#define A_MM2S_0_DONE   0x1
#define A_MM2S_0_ADDR   0x2
#define A_MM2S_0_BYTES  0x3
#define A_MM2S_0_TUSER  0x4
#define A_MM2S_1_DONE   0x5
#define A_MM2S_1_ADDR   0x6
#define A_MM2S_1_BYTES  0x7
#define A_MM2S_1_TUSER  0x8
#define A_MM2S_2_DONE   0x9
#define A_MM2S_2_ADDR   0xA
#define A_MM2S_2_BYTES  0xB
#define A_MM2S_2_TUSER  0xC
#define A_S2MM_DONE     0xD
#define A_S2MM_ADDR     0xE
#define A_S2MM_BYTES    0xF

#include "wrapper.h"


extern EXT_C u8 dma_loopback(Memory_st *restrict mp, void *p_config) {
 
  #ifdef SIM // only read/write files in simulation
    FILE *fp;
    char f_path [1000];
    int bytes;

    WAIT_INIT(DMA_WAIT);

    sprintf(f_path, "%s/kxa.bin", TO_STRING(DIR));
    fp = fopen(f_path, "rb");
    debug_printf("DEBUG: Reading from file %s \n", f_path);
    if(!fp) debug_printf("ERROR! File not found: %s \n", f_path);
    bytes = fread(mp->k, 1, sizeof(mem_phy.k) + sizeof(mem_phy.x) + sizeof(mem_phy.a), fp);
    fclose(fp);
  #endif
  
  // Start DMA
  set_config(p_config, A_MM2S_0_ADDR , addr_64to32(mem_phy.k));
  set_config(p_config, A_MM2S_0_BYTES,      sizeof(mem_phy.k));
  set_config(p_config, A_MM2S_1_ADDR , addr_64to32(mem_phy.x));
  set_config(p_config, A_MM2S_1_BYTES,      sizeof(mem_phy.x));
  set_config(p_config, A_MM2S_2_ADDR , addr_64to32(mem_phy.a));
  set_config(p_config, A_MM2S_2_BYTES,      sizeof(mem_phy.a));
  set_config(p_config, A_S2MM_ADDR   , addr_64to32(mem_phy.y));
  set_config(p_config, A_S2MM_BYTES  ,      sizeof(mem_phy.y));
  set_config(p_config, A_START       , 1);  // Start


  WAIT(!(get_config(p_config, A_S2MM_DONE)), DMA_WAIT);

  #ifdef SIM
    sprintf(f_path, "%s/y.bin", TO_STRING(DIR));
    fp = fopen(f_path, "wb");
    debug_printf("DEBUG: Writing to file %s \n", f_path);
    if(!fp) debug_printf("ERROR! File not found: %s \n", f_path);
    bytes = fwrite(mp->y, 1, sizeof(mem_phy.y), fp);
    fclose(fp);
  #endif
  return 0;
}
