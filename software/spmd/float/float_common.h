#ifndef _FLOAT_COMMON_H_
#define _FLOAT_COMMON_H_

#define N 10
#define ERROR_CODE          0x44444444
#define PASS_CODE           0x0

int print_value( unsigned int *p);

#define LOAD_STORE_TESTID   0x4
#define MOVE_TESTID         0x8
#define BYPASS_TESTID       0xC

void load_store_test(float *src);
void move_test(float *src);
void bypass_test(float *src);

#endif
