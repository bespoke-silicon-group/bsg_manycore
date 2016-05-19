
#include "bsg_manycore.h"

int foo = 0xFFFFFFFF;
char *t = (char *) &foo;

int bsg_x = 0;
int bsg_y = 0;

int main()
{
  bsg_remote_store_char(0,0,&t[3],3);
  bsg_remote_store_char(0,0,&t[2],2);
  bsg_remote_store_char(0,0,&t[1],1);
  bsg_remote_store_char(0,0,&t[0],0);
  bsg_wait_while(bsg_volatile_access(foo) != 0x03020100);

  bsg_finish();
}

