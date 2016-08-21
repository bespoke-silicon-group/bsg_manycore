#ifndef _FLOAT_COMMON_H_
#define _FLOAT_COMMON_H_

#define N 10
#define ERROR_CODE          0x44444444
#define PASS_CODE           0x0

int print_value( unsigned int *p);

#define LOAD_STORE_TESTID           0x4
#define MOVE_TESTID                 0x8
#define BYPASS_ALU_FPI_TESTID       0xC
#define BYPASS_FPI_FPI_TESTID       0x10
#define BYPASS_FPI_ALU_TESTID       0x14
#define CVT_SGN_CLASS_TESTID        0x18
#define FAM_TESTID                  0x1C
#define STALL_FAM_FPI_TESTID        0x20
#define FCSR_TESTID                 0x24

void load_store_test(float *src);
void move_test(float *src);
void bypass_alu_fpi_test(float *src);
void bypass_fpi_fpi_test(float *src);
void bypass_fpi_alu_test(float *src);
void cvt_sgn_class_test();
void fam_test(float *src);
void stall_fam_fpi_test(float *src);
void fcsr_test(float *src);

#endif
