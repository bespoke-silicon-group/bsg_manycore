#include <stdint.h>

int64_t tohost;
int64_t fromhost;

#ifdef __spike_run__
const int spike_run = 1;
#else
const int spike_run = 0;
#endif
