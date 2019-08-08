#include <string.h>
#include <stdarg.h>

int varfunc(const char*, ...);

int varfunc(const char* fmt, ...){
  va_list args;
  va_start(args, fmt);
  return strlen(va_arg(args, char*));
}
