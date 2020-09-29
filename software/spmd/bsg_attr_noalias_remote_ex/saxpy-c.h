#ifndef __SAXPY_C_H
#define __SAXPY_C_H

#include "saxpy.h"
#include <bsg_manycore.h>

#ifdef __cplusplus
extern "C"
#endif
void saxpy_c(float bsg_attr_remote * bsg_attr_noalias A, float bsg_attr_remote * bsg_attr_noalias B, float bsg_attr_remote * bsg_attr_noalias C, float alpha);

#ifdef __cplusplus
extern "C"
#endif
void saxpy_c_moreunroll(float bsg_attr_remote * bsg_attr_noalias A, float bsg_attr_remote * bsg_attr_noalias B, float bsg_attr_remote * bsg_attr_noalias C, float alpha);

#endif // __SAXPY_C_H
