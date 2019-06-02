#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char* argv[]) {
  printf("args = %d\n", argc);

  for(int a=0; a<argc; a++) {
    printf("%s\n", argv[a]);
  }

  return 0;
}
