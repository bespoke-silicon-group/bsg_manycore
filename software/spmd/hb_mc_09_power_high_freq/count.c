#include <stdio.h>

void main() {
  volatile float s = 0.0f;
  for (int i = 0; i < 1000000000; i++) {
    for (int j = 0; j < 64; j++) {
      s += 1.0f;
    }
  }

  printf("%f\n", s);
}
