/**
 *  main.c
 *
 *  float vector test
 *
 *  check values are pre-computed by x86 machines, and are used to validate that 
 *  the values computed by manycore FPU is numerically correct.
 *
 */


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "data.h"

#define NUM_ITER 1 // number of iteration
#define N 256      // data array size
#define UNROLL_SIZE 8

#define flt(X) (*(float*)&X)
#define hex(X) (*(int*)&X)

/* DRAM memory space to do work */
float _vec3[N] __attribute__ ((section (".dram"))) = {0.0};
float _mat1[N*N] __attribute__ ((section (".dram"))) = {0.0};
float _conv_1d_tmp[63] __attribute__ ((section (".dram"))) = {0.0};
float _dot_product_tmp[N] __attribute__ ((section (".dram"))) = {0.0};

/**/
float _kernel5[5] = {0.0};

/* various math-related functions */
unsigned int fhash(float* vec, unsigned int n);
unsigned int fhash2(float* vec, unsigned int n, unsigned int m);
float unrolled_sum(float* vec, unsigned int n);
float vector_sum(float* vec, unsigned int n);
void vector_add(float* dest, float* vec1, float* vec2, unsigned int n);
void vector_mul(float* dest, float* vec1, float* vec2, unsigned int n);
void vector_scale(float* dest, float* vec, float scalar, unsigned int n);
float dot_product(float* vec1, float* vec2, unsigned int n);
void conv_1d(float *dest, float* vec, float* kernel, unsigned int n, unsigned int kn);

/* testing procedures */
void test_unrolled_sum();
void test_vector_sum();
void test_dot_product();
void test_scale_vector();
void test_vector_multiply();
void test_conv_1d();

int main()
{
  bsg_set_tile_x_y();

  if ((__bsg_x == 0) && (__bsg_y == 0))
  {
    bsg_printf("=================\n");
    bsg_printf("Float Vector Test\n");
    bsg_printf("=================\n");

    bsg_print_stat(0);
    for (int i = 0; i < NUM_ITER; i++)
    {
      bsg_printf("Iteration=%d\n", i);
      test_unrolled_sum();
      test_vector_sum();
      test_dot_product();
      test_scale_vector();
      test_vector_multiply();
      test_conv_1d();
    }
    bsg_print_stat(0xdead);

    bsg_finish();
  }

  bsg_wait_while(1);
}


unsigned int fhash(float * vec, unsigned int n)
{
  unsigned int hash = 0;

  for (unsigned int i = 0; i < n; i++)
  {
    hash = (hash>>3) ^ (hex(vec[i])<<3);
  }

  return hash;
}

unsigned int fhash2(float *mat, unsigned int n, unsigned int m)
{
  unsigned int hash = 0;

  for (unsigned int i = 0; i < n; i++)
  {
    for (unsigned int j = 0; j < m; j++)
    {
      hash = (hash>>3) ^ (hex(mat[m*i+j])<<3); 
    }
  }

  return hash;
}


float unrolled_sum(float* vec, unsigned int n)
{
  unsigned int loop_count = n / UNROLL_SIZE;
  unsigned int remainder = n % UNROLL_SIZE;
  float temp[UNROLL_SIZE] = {0.0};
  float sum = 0;

  for (int i = 0; i < loop_count; i++)
  {
    for (int j = 0; j < UNROLL_SIZE; j++)
    {
      temp[j] = vec[UNROLL_SIZE*i+j];
    }

    for (int j = 0; j < UNROLL_SIZE; j++)
    {
      sum += temp[j];
    }
  }

  for (int i = 0; i < remainder; i++)
  {
    temp[i] = vec[(loop_count*UNROLL_SIZE)+i];
  }

  for (int i = 0; i < remainder; i++)
  {
    sum += temp[i];
  }

  return sum;
}

float vector_sum(float *vec, unsigned int n)
{
  float s = 0;
  for (int i = 0; i < n; i++)
  {
    s += vec[i];
  }
  return s;
}

void vector_add(float* dest, float* vec1, float* vec2, unsigned int n)
{
  for (int i = 0; i < n; i++)
  {
    dest[i] = vec1[i] + vec2[i];
  }
}

void vector_mul(float* dest, float* vec1, float* vec2, unsigned int n)
{
  for (int i = 0; i < n; i++)
  {
    dest[i] = vec1[i] * vec2[i];
  }
}

void vector_scale(float* dest, float* vec, float scalar, unsigned int n)
{
  for (int i = 0; i < n; i++)
  {
    dest[i] = vec[i] * scalar;
  }
}



float dot_product(float* vec1, float* vec2, unsigned int n)
{
  vector_mul(_dot_product_tmp, vec1, vec2, n);
  return vector_sum(_dot_product_tmp, n);
}



/**
 *  conv_1d
 */

void conv_1d(float *dest, float* vec, float* kernel, unsigned int n, unsigned int kn)
{
  if (kn > 63 || kn % 2 == 0)
  {
    bsg_printf("kernel size should be smaller than 64 and an odd number.\n"); 
    bsg_fail();
  }

  // assume kn is odd number.
  int krad = kn / 2; // kernel radius

  for (int i = 0; i < n; i++)
  {
    for (int j = -krad; j <= krad; j++)
    {
      int v_idx = i + j;
      int k_idx = j + krad;  

      _conv_1d_tmp[k_idx] = (v_idx >= 0 && v_idx < n)
        ? vec[v_idx]
        : 0;
    }

    dest[i] = dot_product(kernel, _conv_1d_tmp, kn);
  }  
}


////////////////////////
/* testing procedures */
////////////////////////

void test_unrolled_sum()
{
  bsg_printf("Testing unrolled sum...\n"); 

  float sum1 = unrolled_sum(_vec1, N);
  float sum2 = unrolled_sum(_vec2, N);

  bsg_printf("sum1: %x\n", hex(sum1));
  bsg_printf("sum2: %x\n", hex(sum2));

  if (hex(sum1) != 0x4477b7e2)
    bsg_fail();

  if (hex(sum2) != 0xc312d0c0)
    bsg_fail();
}


void test_vector_sum()
{
  bsg_printf("Testing vector sum...\n");

  vector_add(_vec3, _vec1, _vec2, N);

  unsigned int fhash0 = fhash(_vec3, N);
  bsg_printf("fhash: %x\n", fhash0);

  if (hex(fhash0) != 0x120c5af2)
    bsg_fail();
}


void test_dot_product()
{
  bsg_printf("Testing dot product...\n");

  float dp = dot_product(_vec1, _vec2, N);

  bsg_printf("dot_product: %x\n", hex(dp));

  if (hex(dp) != 0x47852310)
    bsg_fail();
}


void test_scale_vector()
{
  bsg_printf("Testing scale vector...\n");

  float scalar1 = 3.103;
  float scalar2 = -0.231;

  vector_scale(_vec3, _vec1, scalar1, N); 

  unsigned int fhash1 = fhash(_vec3, N); 

  bsg_printf("fhash1: %x\n", fhash1);
  if (fhash1 != 0x1f70bd30)
    bsg_fail();

  vector_scale(_vec3, _vec2, scalar2, N); 

  unsigned int fhash2 = fhash(_vec3, N);

  bsg_printf("fhash2: %x\n", fhash2);
  if (fhash2 != 0x087cb971)
    bsg_fail();
};



void test_vector_multiply()
{
  bsg_printf("Testing vector multiply...\n");

  for (int i = 0; i < 16; i++)
  {
    for (int j = 0; j < 16; j++)
    {
      _mat1[i*16+j] = _vec1[i] * _vec2[j];
    }
  }  

  unsigned int hash = fhash2(_mat1, 16, 16);

  bsg_printf("hash: %x\n", hash);
  if (hash != 0x2cfc9f99)
    bsg_fail();
}


void test_conv_1d()
{
  bsg_printf("Testing 1D convolution...\n");  

  float kernel[5] = {1, -1, 2, -1, 1};

  /*  
  for (int i = 0; i < N; i++)
  {
    float sum = 0.0;
    for (int j = -kr; j <= kr; j++)
    {
      int i_eff = i + j;
      if (i_eff >= 0 && i_eff < N)
      {
         sum += kernel[j+kr] * _vec1[i];
      } 
    }

    _vec3[i] = sum;
  }
  */
  conv_1d(_vec3, _vec1, kernel, N, 5);

  //for (int i = 0; i < N; i++)
  //{
  //  bsg_printf("%d: %x\n", i, hex(_vec3[i]));
 // }

  unsigned int hash = fhash(_vec3, N);
  bsg_printf("hash: %x\n", hash);
  if (hash != 0x1a55f7ef)
    bsg_fail();
}







