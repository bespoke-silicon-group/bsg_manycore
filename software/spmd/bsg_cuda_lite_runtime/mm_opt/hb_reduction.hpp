#ifndef _HB_REDUCTION_H
#define _HB_REDUCTION_H

#include <hb_tiled_for.hpp>
#include <kernel_common.hpp>

//====================================================================
// Reduction mode used in LossNLL and other loss functions
//====================================================================

enum Reduction {
  None,             // Do not reduce
  Mean,             // (Possibly weighted) mean of losses
  Sum,              // Sum losses
  END
};

//====================================================================
// Calculate how many input elements to produce one output
//====================================================================

template<typename scalar_t>
inline uint32_t calc_elements_per_output(HBTensor<scalar_t> out,
                                         HBTensor<scalar_t> in,
                                         uint32_t num_reduction_dim) {
  // corner case: iterator appears to be 1d but generating n outputs
  //              1 input element per output
  if(in.ndim() == 1 && out.numel() == in.numel()) {
    return 1;
  }
  // there could be more than 1 dims
  uint32_t elements_to_collect = in.dim(0);
  for(auto i = 1; i < num_reduction_dim; i++) {
    elements_to_collect *= in.dim(i);
  }
  return elements_to_collect;
}

//====================================================================
// Binary reductions -- sum, mean, etc.
//
// ndim -> number of dims in reduction iterator -- this may not equal
//         to the input shape
// num_reduction_dim -> number of dims to be reduced
// elements_per_output -> how many input elements to create one output
// reduce -> how to process a new input element
// project -> how to do postprocessing on result
//
// 04/02/2020 Bandhav Veluri and Lin Cheng
//====================================================================

// Potential cases:
// 1D input -- 1 reduction dim -- trivial
// 2D input -- 1 reduction dim
// 2D input -- 2 reduction dim -- trivial
// 3D input -- 1 reduction dim
// 3D input -- 2 reduction dim
// 3D input -- 3 reduction dim -- trivial
// 4D input -- 1 reduction dim
// 4D input -- 2 reduction dim
// 4D input -- 3 reduction dim
// 4D input -- 4 reduction dim -- trivial

// Trivial case -- reduce to 1 output

template<typename scalar_t, typename F1, typename F2>
inline void binary_reduction_simple(HBTensor<scalar_t> out,
                                    HBTensor<scalar_t> in,
                                    F1 reduce, F2 project) {
  hb_assert_msg(out.numel() == 1, "reduction_simple only handles trivial case");

  __remote scalar_t* data[2];
  data[0] = (__remote scalar_t*)out.data_ptr();
  data[1] = (__remote scalar_t*)in.data_ptr();
  scalar_t* buffer = (scalar_t*)g_reduction_buffer;

  //-----------------------------
  // partial_result
  //-----------------------------
  scalar_t result = 0;

  // is_trivial_1d
  if(in.ndim() == 1) {
    //-----------------------------
    // collect metadata
    //-----------------------------
    uint32_t strides[2];
    strides[0] = (out.get_strides())[0];
    strides[1] = (in.get_strides())[0];

    //-----------------------------
    // iterating over all elementes
    //-----------------------------
    hb_tiled_range(in.numel(), [&](size_t start, size_t end) {
      __remote scalar_t* in_dp = (data[1] + strides[1] * start);
      for(size_t i = start; i < end; i++) {
        reduce(result, *in_dp);
        in_dp += strides[1];
      }
    });
  } else {
    //-----------------------------
    // iterating over all elementes
    //-----------------------------
    hb_tiled_for(in.numel(), [&](size_t idx) {
      __remote scalar_t* in_dp = (__remote scalar_t*)(data[1] + offset_calc(idx, in));
      reduce(result, *in_dp);
    });
  }
  buffer[__bsg_id] = result;
  g_barrier.sync();

  if(__bsg_id == 0) {
    result = 0;
    for(size_t idx = 0; idx < bsg_tiles_X * bsg_tiles_Y; idx++) {
      result += buffer[idx];
    }
    // produce final result
    __remote scalar_t* out_dp = (__remote scalar_t*)(data[0]);
    *out_dp = project(result);
  }

  g_barrier.sync();
}

template<typename scalar_t, typename F1, typename F2>
inline void binary_reduction(HBTensor<scalar_t>out,
                             HBTensor<scalar_t>in,
                             uint32_t ndim, uint32_t num_reduction_dim,
                             uint32_t elements_per_output,
                             F1 reduce, F2 project) {
  if(out.numel() == 1) {
    binary_reduction_simple(out, in, reduce, project);
    return;
  }

  switch(ndim) {
    case 1:
      // There is this corner case, in which each output is produced by only
      // one input element
      hb_assert_msg(out.numel() == in.numel(),
                     "This case should be handled by reduction_simple?");
      hb_tiled_for(out.numel(), [&](size_t n) {
        out(n) = project(in(n));
      });
      break;
    case 2:
      if(num_reduction_dim == 1) {
        // 2D input -- 1 reduction dim
        // parallelize over output elements
        hb_tiled_for(out.numel(), [&](size_t n) {
          // reduction result init to 0
          scalar_t result = 0;
          size_t d = 0;
          if (elements_per_output > 16) {
            for(; d < elements_per_output - 8; d += 8) {
              register scalar_t tmp0 = in(d, n);
              register scalar_t tmp1 = in(d + 1, n);
              register scalar_t tmp2 = in(d + 2, n);
              register scalar_t tmp3 = in(d + 3, n);
              register scalar_t tmp4 = in(d + 4, n);
              register scalar_t tmp5 = in(d + 5, n);
              register scalar_t tmp6 = in(d + 6, n);
              register scalar_t tmp7 = in(d + 7, n);
              asm volatile("": : :"memory");
              reduce(result, tmp0);
              reduce(result, tmp1);
              reduce(result, tmp2);
              reduce(result, tmp3);
              reduce(result, tmp4);
              reduce(result, tmp5);
              reduce(result, tmp6);
              reduce(result, tmp7);
            }
          }
          for(; d < elements_per_output; d++) {
            reduce(result, in(d, n));
          }
          out(0, n) = project(result);
        });
      } else {
        hb_assert_msg(false, "Invalid number of reduction dims");
      }
      break;
    case 3:
      if(num_reduction_dim == 1) {
        // 3D input -- 1 reduction dim
        // parallelize over output elements
        hb_tiled_for(out.numel(), [&](size_t n) {
          // reduction result init to 0
          scalar_t result = 0;
          uint32_t dim1 = n % in.dim(1);
          uint32_t dim2 = n / in.dim(1);
          size_t d = 0;
          if (elements_per_output > 16) {
            for(; d < elements_per_output - 8; d += 8) {
              register scalar_t tmp0 = in(d, dim1, dim2);
              register scalar_t tmp1 = in(d + 1, dim1, dim2);
              register scalar_t tmp2 = in(d + 2, dim1, dim2);
              register scalar_t tmp3 = in(d + 3, dim1, dim2);
              register scalar_t tmp4 = in(d + 4, dim1, dim2);
              register scalar_t tmp5 = in(d + 5, dim1, dim2);
              register scalar_t tmp6 = in(d + 6, dim1, dim2);
              register scalar_t tmp7 = in(d + 7, dim1, dim2);
              asm volatile("": : :"memory");
              reduce(result, tmp0);
              reduce(result, tmp1);
              reduce(result, tmp2);
              reduce(result, tmp3);
              reduce(result, tmp4);
              reduce(result, tmp5);
              reduce(result, tmp6);
              reduce(result, tmp7);
            }
          }
          for(; d < elements_per_output; d++) {
            reduce(result, in(d, dim1, dim2));
          }
          out(0, dim1, dim2) = project(result);
        });
      } else if(num_reduction_dim == 2) {
        // 3D input -- 2 reduction dim
        // parallelize over output elements
        hb_tiled_for(out.numel(), [&](size_t n) {
          // reduction result init to 0
          scalar_t result = 0;
          for(size_t d = 0; d < elements_per_output; d++) {
            uint32_t dim0 = d % in.dim(0);
            uint32_t dim1 = d / in.dim(0);
            reduce(result, in(dim0, dim1, n));
          }
          out(0, 0, n) = project(result);
        });
      } else {
        hb_assert_msg(false, "Invalid number of reduction dims");
      }
      break;
    default:
      hb_assert_msg(false, "Invalid number of dims for reduction kernel");
  }
}

#endif
