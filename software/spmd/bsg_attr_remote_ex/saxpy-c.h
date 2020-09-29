#ifndef __SAXPY_C_H
#define __SAXPY_C_H

#include "saxpy.h"

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_c(float  *A, float  *B, float *C, float alpha);
#ifdef __cplusplus
extern "C" 
#endif
void saxpy_c_remote(float bsg_attr_remote * A, float bsg_attr_remote * B, float bsg_attr_remote * C, float alpha);

#endif // __SAXPY_C_H
