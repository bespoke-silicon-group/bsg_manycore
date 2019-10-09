#ifndef _RAW_H
#define _RAW_H

#ifndef __host__

  #include "bsg_manycore.h"
  #include "bsg_manycore_arch.h"
  #include "bsg_set_tile_x_y.h"

#endif

#ifdef __host__

  #define bsg_remote_ptr_io_store(x, y, val) \
    printf("store to io: %d\n", val)
  
  #define bsg_print_time() // nothing here for now

#elif __spike__

  #include "spike.h"

#endif

#define raw_get_tile_num() 0

#ifndef __spike__
  
  #define raw_test_pass_reg(val) \
    bsg_remote_ptr_io_store(IO_X_INDEX, 0, val)
  
  #define __MINNESTART__ ({ \
    printf("STRAT: "); \
    bsg_print_time(); \
    printf("\n");})
  
  #define __MINNEEND__ ({ \
    printf("END: "); \
    bsg_print_time(); \
    printf("\n");})

#else
  
  #define raw_test_pass_reg(val) \
    replace_spike_call(remote_ptr_io_store, IO_X_INDEX, 0, val);
  
  #define __MINNESTART__ ({ \
    printf("STRAT: "); \
    replace_spike_call(print_time); \
    printf("\n");})
  
  #define __MINNEEND__ ({ \
    printf("END: "); \
    replace_spike_call(print_time); \
    printf("\n");})

#endif

   
void timebegin();
void timeend();

#endif // _RAW_H
