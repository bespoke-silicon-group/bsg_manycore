
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int main()
{
  char  Greeting[32] = "Hello From Core ";
  int i;

  bsg_set_tile_x_y();

  bsg_remote_ptr_io_store(IO_X_INDEX,0x1260,bsg_x);
  bsg_remote_ptr_io_store(IO_X_INDEX,0x1264,bsg_y);

 // bsg_remote_ptr_io_store(IO_X_INDEX,0x1234,0x13);

  if ((bsg_x == bsg_tiles_X-1) && (bsg_y == bsg_tiles_Y-1)) {

     for( i=0; i<32; i++){
        if( Greeting[i] == '\0') break;
        bsg_putchar( Greeting[i] );
     } 

     char x_char = (char) bsg_x + '0';
     char y_char = (char) bsg_y + '0';
     bsg_putchar(x_char);
     bsg_putchar(',');
     bsg_putchar(y_char);
     bsg_putchar('\n');

    bsg_finish();
  }

  bsg_wait_while(1);
}

