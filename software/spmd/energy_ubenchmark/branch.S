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
  j energy_start

branch100:
  bsg_asm_saif_end
  j pass
branch99: beq x0, x0, branch100
branch98: beq x1, x1, branch99
branch97: beq x2, x2, branch98
branch96: beq x3, x3, branch97
branch95: beq x4, x4, branch96
branch94: beq x5, x5, branch95
branch93: beq x6, x6, branch94
branch92: beq x7, x7, branch93
branch91: beq x8, x8, branch92
branch90: beq x9, x9, branch91
branch89: beq x10, x10, branch90
branch88: beq x11, x11, branch89
branch87: beq x12, x12, branch88
branch86: beq x13, x13, branch87
branch85: beq x14, x14, branch86
branch84: beq x15, x15, branch85
branch83: beq x16, x16, branch84
branch82: beq x17, x17, branch83
branch81: beq x18, x18, branch82
branch80: beq x19, x19, branch81
branch79: beq x20, x20, branch80
branch78: beq x21, x21, branch79
branch77: beq x22, x22, branch78
branch76: beq x23, x23, branch77
branch75: beq x24, x24, branch76
branch74: beq x25, x25, branch75
branch73: beq x26, x26, branch74
branch72: beq x27, x27, branch73
branch71: beq x28, x28, branch72
branch70: beq x29, x29, branch71
branch69: beq x30, x30, branch70
branch68: beq x31, x31, branch69
branch67: beq x0, x0, branch68
branch66: beq x1, x1, branch67
branch65: beq x2, x2, branch66
branch64: beq x3, x3, branch65
branch63: beq x4, x4, branch64
branch62: beq x5, x5, branch63
branch61: beq x6, x6, branch62
branch60: beq x7, x7, branch61
branch59: beq x8, x8, branch60
branch58: beq x9, x9, branch59
branch57: beq x10, x10, branch58
branch56: beq x11, x11, branch57
branch55: beq x12, x12, branch56
branch54: beq x13, x13, branch55
branch53: beq x14, x14, branch54
branch52: beq x15, x15, branch53
branch51: beq x16, x16, branch52
branch50: beq x17, x17, branch51
branch49: beq x18, x18, branch50
branch48: beq x19, x19, branch49
branch47: beq x20, x20, branch48
branch46: beq x21, x21, branch47
branch45: beq x22, x22, branch46
branch44: beq x23, x23, branch45
branch43: beq x24, x24, branch44
branch42: beq x25, x25, branch43
branch41: beq x26, x26, branch42
branch40: beq x27, x27, branch41
branch39: beq x28, x28, branch40
branch38: beq x29, x29, branch39
branch37: beq x30, x30, branch38
branch36: beq x31, x31, branch37
branch35: beq x0, x0, branch36
branch34: beq x1, x1, branch35
branch33: beq x2, x2, branch34
branch32: beq x3, x3, branch33
branch31: beq x4, x4, branch32
branch30: beq x5, x5, branch31
branch29: beq x6, x6, branch30
branch28: beq x7, x7, branch29
branch27: beq x8, x8, branch28
branch26: beq x9, x9, branch27
branch25: beq x10, x10, branch26
branch24: beq x11, x11, branch25
branch23: beq x12, x12, branch24
branch22: beq x13, x13, branch23
branch21: beq x14, x14, branch22
branch20: beq x15, x15, branch21
branch19: beq x16, x16, branch20
branch18: beq x17, x17, branch19
branch17: beq x18, x18, branch18
branch16: beq x19, x19, branch17
branch15: beq x20, x20, branch16
branch14: beq x21, x21, branch15
branch13: beq x22, x22, branch14
branch12: beq x23, x23, branch13
branch11: beq x24, x24, branch12
branch10: beq x25, x25, branch11
branch9: beq x26, x26, branch10
branch8: beq x27, x27, branch9
branch7: beq x28, x28, branch8
branch6: beq x29, x29, branch7
branch5: beq x30, x30, branch6
branch4: beq x31, x31, branch5
branch3: beq x0, x0, branch4
branch2: beq x1, x1, branch3
branch1: beq x2, x2, branch2

energy_start:
  bsg_asm_saif_start
  beq x0, x0, branch1   // predict taken

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  j pass_loop
