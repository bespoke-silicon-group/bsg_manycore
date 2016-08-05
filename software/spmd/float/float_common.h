#ifndef _FLOAT_COMMON_H_
#define _FLOAT_COMMON_H_

#define N 10
#define ERROR_CODE          0x44444444
#define PASS_CODE           0x0

int print_value( unsigned int *p);

#define LOAD_STORE_TESTID   0x4
#define MOVE_TESTID         0x8

int load_store_teste(float *src, float *dst);
int move_teste(float *src);

#endif
