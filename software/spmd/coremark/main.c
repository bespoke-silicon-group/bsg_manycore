#include "bsg_manycore.h"

//this macro will defined in Makefile, indicates which rocc can be wrote into
//#define bsg_active_rocc_index
int main()
{
  int i;

  bsg_wait_while(1);
}

////////////////////////////////////////////////////////////////
//Print the current manycore configurations
#pragma message (bsg_VAR_NAME_VALUE( bsg_tiles_X )  )
#pragma message (bsg_VAR_NAME_VALUE( bsg_tiles_Y )  )
