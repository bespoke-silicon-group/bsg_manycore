from random import randrange
from numpy import histogram

RANGE     = 32
DATA_SIZE = 1024

data = []
for i in range(DATA_SIZE):
    data.append(randrange(0,RANGE))

hist, which = histogram(data, bins=list(range(RANGE+1)))

print('__attribute__((section(".dram"))) int data [%d] = {' % DATA_SIZE)
for d in data:
    print('  %d,' % d)
print('};')

print('int answers [%d] = {' % RANGE)
for (v,w) in zip(hist,which):
    print('  [%d] = %d,' % (w,v))
print('};')
