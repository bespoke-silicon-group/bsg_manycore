#ifndef _BYPASS_COMMON_H_
#define _BYPASS_COMMON_H_

#define N 10
#define ERROR_CODE          0x44444444
#define PASS_CODE           0x0

int print_value( unsigned int *p);

#define BYPASS_CORE_TESTID           0x4

void bypass_core_test(unsigned int *src);

#endif
