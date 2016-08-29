#ifndef _FLOAT_COMMON_H_
#define _FLOAT_COMMON_H_

#define N 10
#define ERROR_CODE          0x44444444
#define PASS_CODE           0x0

int print_value( unsigned int *p);

#define CVT_SGN_CLASS_TESTID        0x18
#define FAM_TESTID                  0x1C
#define STALL_FAM_FPI_TESTID        0x20
#define FCSR_TESTID                 0x24
#define FMAC_TESTID                 0x28

void cvt_sgn_class_test();
void fam_test(float *src);
void stall_fam_fpi_test(float *src);
void fcsr_test(float *src);
void fmac_test(float *src);

#endif
