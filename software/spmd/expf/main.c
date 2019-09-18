#include <math.h>
#include <stdio.h>

float data = 3.4;

int main() {
  union {
    int i;
    float f;
  } res;

  res.f = expf(data);

  printf("%x\n", res.i);

  return 0;
}
