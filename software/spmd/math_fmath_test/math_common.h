//Note: copied from /spmd/mul_div/mul_div_common.h

#ifndef _MUL_DIV_COMMON_H_
#define _MUL_DIV_COMMON_H_

#define N 10
#define K 64
#define ERROR_CODE          0x44444444
#define PASS_CODE           0x0

int print_value( unsigned int *p);

#define MUL_DIV_TESTID           0x4

void int_math_test( int *src);
void float_math_test( float *data);

#endif
