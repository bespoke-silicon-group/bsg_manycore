#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main() {
  char c;

  // Read from a file
  FILE *file1 = fopen("test/file1.txt", "r");
  if(file1 == NULL) {
    printf("Cannot open test/file1.txt!\n");
    return -1;
  }

  while((c = fgetc(file1)) != EOF) {
    putchar(c);
  }

  fclose(file1);
  return 0;
}
