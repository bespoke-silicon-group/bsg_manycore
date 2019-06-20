/* main program for benchmarks */

void __attribute__((weak)) initialise_benchmark() {};
int __attribute__((weak)) benchmark() {};
int __attribute__((weak)) verify_benchmark() {};

int __attribute__((weak)) main (int argc, char* argv[])
{
  int i;
  volatile int result;
  int correct;

  initialise_benchmark ();

  for (i = 0; i < REPEAT_FACTOR; i++) {
      initialise_benchmark ();
      result = benchmark ();
  }

  correct = verify_benchmark (result);

  return (!correct);
}	
