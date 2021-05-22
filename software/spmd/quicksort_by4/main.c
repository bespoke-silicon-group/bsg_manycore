#include "bsg_manycore.h"
#include "bsg_barrier.h"
#include "bsg_set_tile_x_y.h"

// Same as quicksort test, but with 4x less data
#define NUM_DATA 128

int data[NUM_DATA] __attribute__ ((section (".dram"))) = {
78113, 17198, 14782, 16082, 9277,  85314, 16469, 30084,
52569, 37570, 38166, 67932, 58458, 53102, 75867, 96332,
842,   70077, 62479, 39741, 89951, 35239, 66788, 82916,
37515, 2778,  57651, 22652, 18587, 70651, 70152, 25686,
30002, 89551, 15633, 87965, 88199, 76903, 64265, 84150,
39286, 46186, 39684, 45319, 79187, 24765, 87722, 28434,
22963, 29593, 45248, 58904, 74658, 85106, 69356, 81062,
95151, 14849, 71309, 91866, 27618, 92831, 70993, 82279,
69459, 49125, 65084, 56782, 13365, 52947, 29800, 36505,
44389, 15180, 7282,  8842,  28547, 16757, 88223, 55053,
78651, 11918, 48023, 56872, 65456, 79328, 22877, 77421,
66976, 95917, 76287, 63778, 42452, 34856, 96273, 66728,
27939, 82898, 23122, 33035, 40497, 99457, 10580, 96097,
77039, 18125, 48743, 81845, 19005, 67238, 273,   33233,
65641, 68438, 74165, 46283, 7831,  43678, 75323, 23181,
97566, 89398, 10363, 71153, 48189, 99549, 43076, 64207};

int data_copy[bsg_tiles_X][bsg_tiles_Y][NUM_DATA] __attribute__ ((section (".dram")));

#define ANSWER 6750377

int local_lst[NUM_DATA];

void quicksort(int* lst, int n)
{
  if (n == 1)
  {
    return;
  }

  int center = lst[0];
  int front = 0;
  int back = n-1;

  for (int i = 1; i < n; i++)
  {
    int temp = lst[i];
    if (temp >= center)
    {
      local_lst[back] = temp;
      back--;
    }
    else
    {
      local_lst[front] = temp;
      front++;
    }
  } 

  if (back == front)
  {
    local_lst[back] = center; 

    for (int i = 0; i < n; i++) 
    {
      lst[i] = local_lst[i];
    }    
    if (front != 0)
    {
      quicksort(lst, front);
    }
    if (back != n-1)
    {
      quicksort(&(lst[back+1]), n-1-back);
    }
  }
  else
  {
    bsg_fail();
  }
}

bsg_barrier     tile0_barrier = BSG_BARRIER_INIT(0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int main()
{
  bsg_set_tile_x_y();

  bsg_barrier_wait( &tile0_barrier, 0, 0);
  

  for (int i = 0; i < NUM_DATA; i++)
    data_copy[bsg_x][bsg_y][i] = data[i];

  quicksort(data_copy[bsg_x][bsg_y], NUM_DATA);


  int sum = data_copy[bsg_x][bsg_y][0];
  for (int i = 0; i < NUM_DATA-1; i++)
  {
    sum += data_copy[bsg_x][bsg_y][i+1];

    if (data_copy[bsg_x][bsg_y][i] > data_copy[bsg_x][bsg_y][i+1])
    {
      bsg_fail();
    }
  }

  if (sum == ANSWER)
  {
          //    bsg_printf("sum: %d, [PASSED]\n", sum);
  }
  else 
  {
    bsg_printf("sum: %d, expected %d, [FAILED]\n", sum,ANSWER);
    bsg_fail();
  }

  bsg_barrier_wait( &tile0_barrier, 0, 0);

  if( bsg_x == 0  && bsg_y == 0)
    bsg_finish();

  bsg_wait_while(1);
}
