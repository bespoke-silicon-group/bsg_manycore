```
Machine.machine.include parameters

- BSG_MACHINE_GLOBAL_X                  =   x-dimension of manycore array.
- BSG_MACHINE_GLOBAL_Y                  =   y-dimension of manycore array (including the io router row).

- BSG_MACHINE_NUM_VCACHE_ROWS           =   number of vcache rows on each side of pod (north and south).
                                            (allowed val = 1,2,4)
- BSG_MACHINE_VCACHE_SET                =   number of sets in each vcache
- BSG_MACHINE_VCACHE_WAY                =   number of ways in each vcache
- BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS   =   number of words in each vcache block.
- BSG_MACHINE_VCACHE_DMA_DATA_WIDTH     =   vcache dma interface data width.
                                            (constraint: 32 <= DMA_DATA_WIDTH <= BLOCK_SIZE*32)
- BSG_MACHINE_NUM_VCACHES_PER_CHANNEL   =   number of vcaches allocated per one HBM2 channel (only for e_vcache_hbm2)
                                            (constraint for single pod: NUM_VCACHES_PER_CHANNEL <= 2*NUM_VCACHE_ROWS*BSG_MACHINE_GLOBAL_X)

- BSG_MACHINE_VCACHE_MISS_FIFO_ELS      =   number of entries in miss fifo (non-blocking vcache only).
- BSG_MACHINE_DRAM_SIZE_WORDS           =   the total size of main memory. 2GB max, but it can be set to lower.
- BSG_MACHINE_DRAM_BANK_SIZE_WORDS      =   the size of address space spanned by each bank.
                                            This is usually BSG_MACHINE_DRAM_SIZE_WORDS divided by BSG_MACHINE_GLOBAL_X.
- BSG_MACHINE_DRAM_INCLUDED             =   This flag indicates whether the main memory is available.
                                            If this flag is set to zero, the manycore can only operate in NO-DRAM mode,
                                            meaning that the vcache is only used as block memory.
- BSG_MACHINE_MAX_EPA_WIDTH             =   Width of word address on the mesh network.
- BSG_MACHINE_MEM_CFG                   =   e_vcache_non_blocking_axi4_nonsynth_mem
- BSG_MACHINE_DRAMSIM3_PKG              =   Specify the dramsim3 setting. (only applicable if BSG_MACHINE_MEM_CFG is hbm2)
- BSG_MACHINE_BRANCH_TRACE_EN           =   Enable branch trace.
- BSG_MACHINE_HETERO_TYPE_VEC           =   Hetero type vector. Default configuration is 'default:0'.
                                            Use this to instantiate custom accelerator instead of vanilla core.

- BSG_MACHINE_NETWORK_CFG               =   Manycore Network configuration (look at bsg_manycore_network_cfg_pkg.v)
- BSG_MACHINE_RUCHE_FACTOR_X            =   Ruche Factor X. Only valid if network config is ruche.

```
