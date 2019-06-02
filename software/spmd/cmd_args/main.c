#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char* argv[]) {
  if(argc == 2) {
    if((strcmp(argv[0], "foo") == 0) 
        && (strcmp(argv[1], "bar") == 0))
      return 0;
  }

  return -1;
}
