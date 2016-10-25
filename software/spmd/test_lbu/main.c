#define bsg_tiles_X  2
#define bsg_tiles_Y  1

extern int bsg_x;
extern int bsg_y;

#define bsg_noc_xbits 1

#define bsg_noc_ybits 1
/*
void __attribute__ ((noinline)) bsg_remote_ptr_io_store(volatile int *vp, int val) { *vp = val; }
*/

#define bsg_remote_ptr_io_store(ptr, value) \
           __asm__ __volatile__("sw %0, 0(%1)" : :"r"(value),"r"(ptr)) ;

int main(int argc, char *argv[])
{
volatile int * remote_ptr = (volatile int *) 
         (  ( 1<< 31)   \
           |( bsg_tiles_Y << ( 31 - (bsg_noc_ybits) ) ) \
           |( bsg_x       << ( 31 - bsg_noc_xbits -bsg_noc_ybits) ) \
           |( (int) ( 0x0 ) ) \
         );

   bsg_remote_ptr_io_store( remote_ptr, 0x44444444);
}
