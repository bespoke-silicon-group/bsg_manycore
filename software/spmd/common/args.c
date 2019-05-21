#if defined(__bsg_newlib) && defined(__bsg_argc) && defined(__bsg_argv)

int _argc = __bsg_argc;
char* _argv[] = { __bsg_argv };

void set_cmd_args(void) {
  int* sptr = (int*) (4096*2 - 4);

  *sptr = _argc;
  *(sptr-1) = (int) _argv;
}

#endif
