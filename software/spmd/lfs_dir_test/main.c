#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int print_file(char* path) {
  int c;

  FILE *file = fopen(path, "r");
  if(file == NULL) {
    fprintf(stderr, "Cannot open %s!\n", path);
    return -1;
  }

  printf("\nReading %s:\n", path);

  while((c = fgetc(file)) != EOF) {
    putchar(c);
  }

  putchar('\n');

  fclose(file);
  return 0;
}

int main() {
  char* paths[2] = {"test/file1.txt",
                  "test/subtest/file2.txt"};

  for(int i=0; i<2; i++)
    print_file(paths[i]);

  return 0;
}
