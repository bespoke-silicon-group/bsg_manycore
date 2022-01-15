#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  // initialize
  bsg_asm_init_regfile
  li x1, 795645
  li x2, 524350
  li x3, -934085
  li x4, -384010
  li x5, 791501
  li x6, 438203
  li x7, -199726
  li x8, 816235
  li x9, 680653
  li x10, -653941
  li x11, 152395
  li x12, -283350
  li x13, 236652
  li x14, -18900
  li x15, 741102
  li x16, -785371
  li x17, -313643
  li x18, -450383
  li x19, 526230
  li x20, -271876
  li x21, -975568
  li x22, 555034
  li x23, -427763
  li x24, -877907
  li x25, -420512
  li x26, -726513
  li x27, 281666
  li x28, 260228
  li x29, -566400
  li x30, -391277
  li x31, 422697

  // start
  bsg_asm_saif_start
  branch0: beq x0, x0, branch1
  branch1: beq x1, x1, branch2
  branch2: beq x2, x2, branch3
  branch3: beq x3, x3, branch4
  branch4: beq x4, x4, branch5
  branch5: beq x5, x5, branch6
  branch6: beq x6, x6, branch7
  branch7: beq x7, x7, branch8
  branch8: beq x8, x8, branch9
  branch9: beq x9, x9, branch10
  branch10: beq x10, x10, branch11
  branch11: beq x11, x11, branch12
  branch12: beq x12, x12, branch13
  branch13: beq x13, x13, branch14
  branch14: beq x14, x14, branch15
  branch15: beq x15, x15, branch16
  branch16: beq x16, x16, branch17
  branch17: beq x17, x17, branch18
  branch18: beq x18, x18, branch19
  branch19: beq x19, x19, branch20
  branch20: beq x20, x20, branch21
  branch21: beq x21, x21, branch22
  branch22: beq x22, x22, branch23
  branch23: beq x23, x23, branch24
  branch24: beq x24, x24, branch25
  branch25: beq x25, x25, branch26
  branch26: beq x26, x26, branch27
  branch27: beq x27, x27, branch28
  branch28: beq x28, x28, branch29
  branch29: beq x29, x29, branch30
  branch30: beq x30, x30, branch31
  branch31: beq x31, x31, branch32
  branch32: beq x0, x0, branch33
  branch33: beq x1, x1, branch34
  branch34: beq x2, x2, branch35
  branch35: beq x3, x3, branch36
  branch36: beq x4, x4, branch37
  branch37: beq x5, x5, branch38
  branch38: beq x6, x6, branch39
  branch39: beq x7, x7, branch40
  branch40: beq x8, x8, branch41
  branch41: beq x9, x9, branch42
  branch42: beq x10, x10, branch43
  branch43: beq x11, x11, branch44
  branch44: beq x12, x12, branch45
  branch45: beq x13, x13, branch46
  branch46: beq x14, x14, branch47
  branch47: beq x15, x15, branch48
  branch48: beq x16, x16, branch49
  branch49: beq x17, x17, branch50
  branch50: beq x18, x18, branch51
  branch51: beq x19, x19, branch52
  branch52: beq x20, x20, branch53
  branch53: beq x21, x21, branch54
  branch54: beq x22, x22, branch55
  branch55: beq x23, x23, branch56
  branch56: beq x24, x24, branch57
  branch57: beq x25, x25, branch58
  branch58: beq x26, x26, branch59
  branch59: beq x27, x27, branch60
  branch60: beq x28, x28, branch61
  branch61: beq x29, x29, branch62
  branch62: beq x30, x30, branch63
  branch63: beq x31, x31, branch64
  branch64: beq x0, x0, branch65
  branch65: beq x1, x1, branch66
  branch66: beq x2, x2, branch67
  branch67: beq x3, x3, branch68
  branch68: beq x4, x4, branch69
  branch69: beq x5, x5, branch70
  branch70: beq x6, x6, branch71
  branch71: beq x7, x7, branch72
  branch72: beq x8, x8, branch73
  branch73: beq x9, x9, branch74
  branch74: beq x10, x10, branch75
  branch75: beq x11, x11, branch76
  branch76: beq x12, x12, branch77
  branch77: beq x13, x13, branch78
  branch78: beq x14, x14, branch79
  branch79: beq x15, x15, branch80
  branch80: beq x16, x16, branch81
  branch81: beq x17, x17, branch82
  branch82: beq x18, x18, branch83
  branch83: beq x19, x19, branch84
  branch84: beq x20, x20, branch85
  branch85: beq x21, x21, branch86
  branch86: beq x22, x22, branch87
  branch87: beq x23, x23, branch88
  branch88: beq x24, x24, branch89
  branch89: beq x25, x25, branch90
  branch90: beq x26, x26, branch91
  branch91: beq x27, x27, branch92
  branch92: beq x28, x28, branch93
  branch93: beq x29, x29, branch94
  branch94: beq x30, x30, branch95
  branch95: beq x31, x31, branch96
  branch96: beq x0, x0, branch97
  branch97: beq x1, x1, branch98
  branch98: beq x2, x2, branch99
  branch99: beq x3, x3, branch100
  branch100:
    bsg_asm_saif_end

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  j pass_loop
