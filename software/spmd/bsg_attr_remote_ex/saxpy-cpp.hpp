#ifndef __SAXPY_CPP_HPP
#define __SAXPY_CPP_HPP

#include "saxpy.h"

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_cpp(float  *A, float  *B, float *C, float alpha);
#ifdef __cplusplus
extern "C" 
#endif
void saxpy_cpp_remote(float bsg_attr_remote * A, float bsg_attr_remote * B, float bsg_attr_remote * C, float alpha);

#endif // __SAXPY_C_HPP
