// =============================================================
// Workarounds for BSG HW Issues
//
// This header file implementes a set of workarounds for HW
// issues that might be discovered on ASIC. The plan is to
// reproduce the bug in cosimulation and use verilog asserts
// to root cause the line of kernel code triggering the bug.
// After figuring out the line of kernel code triggering the
// bug, the verilog error message can used to find the right
// software fix in this header, and use fix that to patch the
// kernel code.
//
// For example, if a bug is triggered by a WAW violation between:
//
//   sizes = (uint32_t*) ((intptr_t) t->sizes);
//     204: 00c52f03            lw  x30,12(x10)
//   .
//   .
// (and)
//   .
//   .
//   strides[1] = (input.get_strides())[0];
//     3ac: 00092f03            lw  x30,0(x18)
//
// The error message by verilog assertion would start with:
// [ERROR][VCORE] STALL_FORCE_WB WAW HAZARD
//
// A possible workaround is to use the macro BSG_FIX_WAW_HAZARD
// on `sizes`:
//
//   sizes = (uint32_t*) ((intptr_t) t->sizes);
//   BSG_FIX_WAW_HAZARD(sizes);
//   .
//   .
//   strides[1] = (input.get_strides())[0];
// =============================================================

#ifndef _BSG_HW_PATCH_HPP
#define _BSG_HW_PATCH_HPP

// Fixes WAW violations in HW
//
// WAW violations are seen in cosimulation as errors starting with:
// [ERROR][VCORE] STALL_FORCE_WB WAW HAZARD
#define BSG_FIX_WAW_HAZARD(var) \
  do {                         \
    asm volatile (             \
        "mv %0, %1;"           \
        : "=r" ((var))         \
        : "r" ((var))          \
        );                     \
  } while(0)

#endif // _BSG_HW_PATCH_HPP
