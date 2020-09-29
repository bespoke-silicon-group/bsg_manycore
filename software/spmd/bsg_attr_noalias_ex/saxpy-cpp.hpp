#ifndef __SAXPY_CPP_HPP
#define __SAXPY_CPP_HPP

#include "saxpy.h"

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_cpp(float  *  A, float  *  B, float *C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_cpp_const(float const * const A, float const * const B, float * const C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_cpp_noalias(float * bsg_attr_noalias A, float * bsg_attr_noalias B, float * bsg_attr_noalias C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_cpp_noalias_A(float * bsg_attr_noalias * A, float * bsg_attr_noalias C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_cpp_A_noalias(float ** bsg_attr_noalias A, float * bsg_attr_noalias C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_cpp_noalias_noalias(float * bsg_attr_noalias * bsg_attr_noalias A, float * bsg_attr_noalias C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_cpp_noalias_flat(float * bsg_attr_noalias A, float * bsg_attr_noalias C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_cpp_inline(float * A, float * B, float * C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_cpp_cast(float * bsg_attr_noalias A, float * bsg_attr_noalias C, float alpha);

#endif // __SAXPY_C_HPP
