#ifndef __SAXPY_C_H
#define __SAXPY_C_H

#include "saxpy.h"
#include <bsg_manycore.h>

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_c(float  *  A, float  *  B, float *C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_c_const(float const * const A, float const * const B, float * const C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_c_noalias(float * bsg_attr_noalias A, float * bsg_attr_noalias B, float * bsg_attr_noalias C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_c_noalias_A(float * bsg_attr_noalias * A, float * bsg_attr_noalias C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_c_A_noalias(float ** bsg_attr_noalias A, float * bsg_attr_noalias C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_c_noalias_noalias(float * bsg_attr_noalias * bsg_attr_noalias A, float * bsg_attr_noalias C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_c_noalias_flat(float * bsg_attr_noalias A, float * bsg_attr_noalias C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_c_inline(float * A, float * B, float * C, float alpha);

#endif // __SAXPY_C_H
