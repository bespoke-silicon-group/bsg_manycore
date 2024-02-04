import torch
torch.manual_seed(0)

ISIZE = 16
KSIZE = 3
OSIZE = ISIZE-2

# N,C,H,W
input_ = torch.rand((1,1,ISIZE,ISIZE),dtype=torch.float32)
kernel = torch.rand((1,1,KSIZE,KSIZE),dtype=torch.float32)
result = torch.nn.functional.conv2d(input_, kernel)
output = torch.zeros(result.shape, dtype=torch.float32)

def to_c(name, T):
    result = f'float {name}[{T.numel()}] __attribute__ ((section ("dmem"))) = '
    result += "{"
    for i in T.flatten():
        result += str(i.item())
        result += ", "
    result += "};"
    print(result)

print(f"#define ISIZE {ISIZE}")
print(f"#define KSIZE {KSIZE}")
print(f"#define OSIZE {OSIZE}")
to_c("input", input_)
to_c("kernel", kernel)
to_c("output", output)
to_c("expected", result)
