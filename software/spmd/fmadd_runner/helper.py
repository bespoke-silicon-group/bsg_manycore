import ctypes

def int_to_binstr(value: int, width: int) -> str:
    bstr = format(value, f"0{width}b")
    assert len(bstr) == width, f"Value too large -> value={value}, width={width}"
    return bstr


def fp32_to_binstr(value: float) -> str:
    return int_to_binstr(ctypes.c_uint32.from_buffer(ctypes.c_float(value)).value, 32)

def fp32_to_asm_hex(value: float) -> str:
    return str(hex(int(fp32_to_binstr(value), 2))).upper()

start = 2.4
fwd_m = 0.15
fwd_b = 3.7

rev_m = 1.0 / fwd_m
rev_b = -1.0 * (fwd_b / fwd_m)

print(f"li x1, {fp32_to_asm_hex(start)} // {start}")
print(f"li x2, {fp32_to_asm_hex(fwd_m)} // {fwd_m}")
print(f"li x3, {fp32_to_asm_hex(fwd_b)} // {fwd_b}")
print(f"li x4, {fp32_to_asm_hex(rev_m)} // {rev_m}")
print(f"li x5, {fp32_to_asm_hex(rev_b)} // {rev_b}")
print(f"fmv.s.x f1, x1")
print(f"fmv.s.x f2, x2")
print(f"fmv.s.x f3, x3")
print(f"fmv.s.x f4, x4")
print(f"fmv.s.x f5, x5")
print(f"fmv.s.x f6, x0")

if 0:
    import numpy as np
    s  = np.float32(start)
    fm = np.float32(fwd_m)
    fb = np.float32(fwd_b)
    rm = np.float32(rev_m)
    rb = np.float32(rev_b)

    s = s * fm + fb
    s = s * fm + fb
    s = s * fm + fb
    s = s * fm + fb
    s = s * fm + fb
    s = s * fm + fb
    s = s * fm + fb
    s = s * fm + fb

    s = s * rm + rb
    s = s * rm + rb
    s = s * rm + rb
    s = s * rm + rb
    s = s * rm + rb
    s = s * rm + rb
    s = s * rm + rb
    s = s * rm + rb

    print(fp32_to_asm_hex(s))
