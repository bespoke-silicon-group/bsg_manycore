#!/bin/env python3
import random

# Generate random numbers for saxpy.h 

N_ELS = 512
ALPHA = random.uniform(-1, 1)

header = [ "#ifndef __SAXPY_H",
           "#define __SAXPY_H",
           "#define N_ELS {}".format(N_ELS),
           "#define MACRO_ALPHA {}".format(ALPHA)]


a = [str(random.uniform(-1,1)) for i in range(N_ELS)]
b = [str(random.uniform(-1,1)) for i in range(N_ELS)]

with open("saxpy.h", "w") as f:
    f.write("\n".join(header));
    f.write("\n");
    per_line = 10
    
    # Generate A
    f.write("#define MACRO_A {\\\n")
    cur = 0
    while(cur < N_ELS):
        f.write(",".join(a[cur : min(cur + per_line, N_ELS)]))
        cur += per_line
        if(cur <  N_ELS):
            f.write(",\\")
        else:
            f.write("}");
        f.write("\n")

    # Generate B
    f.write("#define MACRO_B {\\\n")
    cur = 0
    while(cur < N_ELS):
        f.write(",".join(a[cur : min(cur + per_line, N_ELS)]))
        cur += per_line
        if(cur <  N_ELS):
            f.write(",\\")
        else:
            f.write("}");
        f.write("\n")

    f.write("#endif // __SAXPY_H\n");

