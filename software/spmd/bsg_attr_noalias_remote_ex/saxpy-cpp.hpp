#ifndef __SAXPY_CPP_HPP
#define __SAXPY_CPP_HPP

#include "saxpy.h"

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_cpp(float bsg_attr_remote * bsg_attr_noalias A, float bsg_attr_remote * bsg_attr_noalias B, float bsg_attr_remote * bsg_attr_noalias C, float alpha);

#ifdef __cplusplus
extern "C" 
#endif
void saxpy_cpp_moreunroll(float bsg_attr_remote * bsg_attr_noalias A, float bsg_attr_remote * bsg_attr_noalias B, float bsg_attr_remote * bsg_attr_noalias C, float alpha);

#endif // __SAXPY_C_HPP
