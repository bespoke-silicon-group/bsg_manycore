import sys
LOOP_SIZE = int(sys.argv[1])

print("#include \"bsg_manycore_arch.h\"")
print("#include \"bsg_manycore_asm.h\"")

print(".text")
print("bsg_asm_init_regfile")


print("li s0, 0")
print("li s1, 100")


print("bsg_asm_saif_start")

print("nop")
print("nop")
print("nop")
print("loop:")
for i in range(LOOP_SIZE-2):
  print("addi s0, s0, 1")
print("addi s1, s1, -1")
print("bne x0, s1, loop")




print("bsg_asm_saif_end")

print("pass:")
print("bsg_asm_finish(IO_X_INDEX, 0)")
print("pass_loop:")
print("j pass_loop")
