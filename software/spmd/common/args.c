#if defined(__bsg_newlib) && defined(__bsg_argc) && defined(__bsg_argv)

extern int _sp;

int _argc = __bsg_argc;
char* _argv[] = { __bsg_argv };

void set_cmd_args(void) {
  _sp = _argc;
  *((&_sp)-1) = (int) _argv;
}

#endif
