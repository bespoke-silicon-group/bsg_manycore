//====================================================================
// Element-wise for helper function
// 03/12/2020 Lin Cheng (lc873@cornell.edu)
//
// Note: assuming a 3D tensor, and you access it with (x, y, z)
// Plain tensor has indices numbered as (0, 1, 2)
// BUT iterator tensor has indices numbered as (2, 1, 0)
//====================================================================

#ifndef _HB_TILED_FOR_HPP
#define _HB_TILED_FOR_HPP

#include <map>
#include <math.h>
#include <initializer_list>
#include <hb_assert.hpp>
#include <hb_tensor.hpp>

// =========================================================
// Linear index to offset
// =========================================================
template<typename scalar_t>
inline uint32_t offset_calc(uint32_t idx, HBTensor<scalar_t> tensor) {
  uint32_t* strides = tensor.get_strides();
  uint32_t* sizes = tensor.get_sizes();
  uint32_t offset = 0;
  for(uint32_t i = 0; i < tensor.ndim(); i++) {
    uint32_t dimx = idx % sizes[i];
    idx /= sizes[i];
    offset += dimx * strides[i];
  }
  return offset;
}

// =========================================================
// Tiled range calculation
// hb_range -> [start, end)
// =========================================================
typedef struct hb_range {
  size_t start;
  size_t end;
} hb_range;

inline void calc_range(hb_range* range, size_t numel,
                       size_t tg_size = bsg_tiles_X * bsg_tiles_Y) {
  // per pod chunk
  size_t len_per_pod  = numel / BSG_POD_DIM + 1;
  // chunk range
  size_t pod_start    = len_per_pod * __bsg_pod_id;
  size_t pod_end      = pod_start + len_per_pod;
  pod_end = (pod_end > numel) ? numel : pod_end;
  if (pod_start >= pod_end) {
    range->start = 0;
    range->end   = 0;
    return;
  }
  size_t pod_size     = pod_end - pod_start;

  // per tile range within a pod
  size_t tile_id = __bsg_id % tg_size;
  size_t len_per_tile = pod_size / tg_size + 1;
  size_t start        = len_per_tile * tile_id;
  size_t end          = start + len_per_tile;
  end = (end > pod_size) ? pod_size : end;
  if (start >= end) {
    range->start = 0;
    range->end   = 0;
    return;
  }

  // range in global idx
  range->start = pod_start + start;
  range->end   = pod_start + end;

  return;
}

// =========================================================
// Tiled Pointwise for
// =========================================================

template<typename scalar_t, typename F, class... Types>
inline void hb_tiled_foreach(F functor,
                             HBTensor<scalar_t> res,
                             Types... args) {
  // Iterating over all elementes
  hb_range range;
  calc_range(&range, res.numel());
  size_t start = range.start;
  size_t end   = range.end;

  // Static dispatch based on number number of operands
  hb_tiled_foreach_impl(
      start, end, functor, res,
      args...,
      (bsg_attr_remote scalar_t*) res.data_ptr(),
      ((bsg_attr_remote scalar_t*) args.data_ptr())...);
}

// Nullary
template<typename scalar_t, typename F, typename... P>
__attribute__((noinline)) void hb_tiled_foreach_impl(
      size_t start, size_t end, F functor,
      HBTensor<scalar_t> res,
      bsg_attr_remote scalar_t* bsg_attr_noalias res_ptr) {
  // is_trivial_1d
  if(res.ndim() == 1) {
    bsg_unroll(16) for(size_t idx = start; idx < end; idx++) {
      res_ptr[idx * res.get_strides()[0]] =
        functor();
    }
  } else {
    bsg_unroll(16) for (size_t idx = start; idx < end; idx++) {
      res_ptr[offset_calc(idx, res)] =
        functor();
    }
  }
}

// Unary
template<typename scalar_t, typename F, typename... P>
__attribute__((noinline)) void hb_tiled_foreach_impl(
      size_t start, size_t end, F functor,
      HBTensor<scalar_t> res,
      HBTensor<scalar_t> tensor_arg0,
      bsg_attr_remote scalar_t* bsg_attr_noalias res_ptr,
      bsg_attr_remote scalar_t* bsg_attr_noalias tensor_data_ptr0) {
  // is_trivial_1d
  if(res.ndim() == 1) {
    bsg_unroll(16) for(size_t idx = start; idx < end; idx++) {
      res_ptr[idx * res.get_strides()[0]] =
        functor(tensor_data_ptr0[idx * tensor_arg0.get_strides()[0]]);
    }
  } else {
    bsg_unroll(16) for (size_t idx = start; idx < end; idx++) {
      res_ptr[offset_calc(idx, res)] =
        functor(tensor_data_ptr0[offset_calc(idx, tensor_arg0)]);
    }
  }
}

// Binary
template<typename scalar_t, typename F, typename... P>
__attribute__((noinline)) void hb_tiled_foreach_impl(
      size_t start, size_t end, F functor,
      HBTensor<scalar_t> res,
      HBTensor<scalar_t> tensor_arg0,
      HBTensor<scalar_t> tensor_arg1,
      bsg_attr_remote scalar_t* bsg_attr_noalias res_ptr,
      bsg_attr_remote scalar_t* bsg_attr_noalias tensor_data_ptr0,
      bsg_attr_remote scalar_t* bsg_attr_noalias tensor_data_ptr1) {
  // is_trivial_1d
  if(res.ndim() == 1) {
    bsg_unroll(16) for(size_t idx = start; idx < end; idx++) {
      res_ptr[idx * res.get_strides()[0]] =
        functor(tensor_data_ptr0[idx * tensor_arg0.get_strides()[0]],
                tensor_data_ptr1[idx * tensor_arg1.get_strides()[0]]);
    }
  } else {
    bsg_unroll(16) for (size_t idx = start; idx < end; idx++) {
      res_ptr[offset_calc(idx, res)] =
        functor(tensor_data_ptr0[offset_calc(idx, tensor_arg0)],
                tensor_data_ptr1[offset_calc(idx, tensor_arg1)]);
    }
  }
}

// Ternary
template<typename scalar_t, typename F, typename... P>
__attribute__((noinline)) void hb_tiled_foreach_impl(
      size_t start, size_t end, F functor,
      HBTensor<scalar_t> res,
      HBTensor<scalar_t> tensor_arg0,
      HBTensor<scalar_t> tensor_arg1,
      HBTensor<scalar_t> tensor_arg2,
      bsg_attr_remote scalar_t* bsg_attr_noalias res_ptr,
      bsg_attr_remote scalar_t* bsg_attr_noalias tensor_data_ptr0,
      bsg_attr_remote scalar_t* bsg_attr_noalias tensor_data_ptr1,
      bsg_attr_remote scalar_t* bsg_attr_noalias tensor_data_ptr2) {
  // is_trivial_1d
  if(res.ndim() == 1) {
    bsg_unroll(16) for(size_t idx = start; idx < end; idx++) {
      res_ptr[idx * res.get_strides()[0]] =
        functor(tensor_data_ptr0[idx * tensor_arg0.get_strides()[0]],
                tensor_data_ptr1[idx * tensor_arg1.get_strides()[0]],
                tensor_data_ptr2[idx * tensor_arg2.get_strides()[0]]);
    }
  } else {
    bsg_unroll(16) for (size_t idx = start; idx < end; idx++) {
      res_ptr[offset_calc(idx, res)] =
        functor(tensor_data_ptr0[offset_calc(idx, tensor_arg0)],
                tensor_data_ptr1[offset_calc(idx, tensor_arg1)],
                tensor_data_ptr2[offset_calc(idx, tensor_arg2)]);
    }
  }
}

// =========================================================
// Tile Element-wise for -- Unary ops -- Special conversion
//
// This function calculates the per tile range automatically
//==========================================================

template<typename scalar_src, typename scalar_dst, typename F>
inline void hb_tiled_foreach_conversion(HBTensor<scalar_dst> res,
                               HBTensor<scalar_src> input,
                               F functor) {

  bsg_attr_remote scalar_dst* res_data = (bsg_attr_remote scalar_dst*)res.data_ptr();
  bsg_attr_remote scalar_src* input_data = (bsg_attr_remote scalar_src*)input.data_ptr();

  // is_trivial_1d
  if(res.ndim() == 1) {

    //-----------------------------
    // collect metadata
    //-----------------------------
    uint32_t strides[2];
    strides[0] = (res.get_strides())[0];
    strides[1] = (input.get_strides())[0];

    //-----------------------------
    // iterating over all elementes
    //-----------------------------
    hb_range range;
    calc_range(&range, res.numel());
    size_t start = range.start;
    size_t end   = range.end;

    res_data += strides[0] * start;
    input_data += strides[1] * start;
    size_t idx = start;
    if (end - start > 4) {
      for (; idx < end - 4; idx += 4) {
        scalar_src input_dp_0 = *(input_data);
        bsg_attr_remote scalar_dst* res_dp_0 = (res_data);
        res_data += strides[0];
        input_data += strides[1];

        scalar_src input_dp_1 = *(input_data);
        bsg_attr_remote scalar_dst* res_dp_1 = (res_data);
        res_data += strides[0];
        input_data += strides[1];

        scalar_src input_dp_2 = *(input_data);
        bsg_attr_remote scalar_dst* res_dp_2 = (res_data);
        res_data += strides[0];
        input_data += strides[1];

        scalar_src input_dp_3 = *(input_data);
        bsg_attr_remote scalar_dst* res_dp_3 = (res_data);
        res_data += strides[0];
        input_data += strides[1];

        *res_dp_0 = functor(input_dp_0);
        *res_dp_1 = functor(input_dp_1);
        *res_dp_2 = functor(input_dp_2);
        *res_dp_3 = functor(input_dp_3);
      }
    }
    for (; idx < end; idx++) {
      bsg_attr_remote scalar_dst* res_dp = (res_data);
      bsg_attr_remote scalar_src* input_dp = (input_data);
      *res_dp = functor(*input_dp);
      res_data += strides[0];
      input_data += strides[1];
    }
  } else if (res.ndim() == 2) {
    // the idea is each tile takes care of the first dim in one shot
    hb_range range;
    calc_range(&range, res.dim(0));
    size_t start = range.start;
    size_t end   = range.end;

    uint32_t* src_strides = input.get_strides();
    uint32_t* src_sizes = input.get_sizes();
    uint32_t* dst_strides = res.get_strides();
    uint32_t* dst_sizes = res.get_sizes();

    for (size_t idx = start; idx < end; idx++) {
      bsg_attr_remote scalar_dst* dst_data = res_data + idx * dst_strides[0];
      bsg_attr_remote scalar_src* src_data = input_data + idx * src_strides[0];

      for (size_t inner = 0; inner < res.dim(1); inner++) {
        scalar_src input_dp_0 = *(src_data);
        bsg_attr_remote scalar_dst* res_dp_0 = (dst_data);
        dst_data += dst_strides[1];
        src_data += src_strides[1];

        *res_dp_0 = functor(input_dp_0);
      }
    }
  } else if (res.ndim() == 3) {
    hb_range range;
    calc_range(&range, res.dim(0) * res.dim(1));
    size_t start = range.start;
    size_t end   = range.end;

    uint32_t* src_strides = input.get_strides();
    uint32_t* src_sizes = input.get_sizes();
    uint32_t* dst_strides = res.get_strides();
    uint32_t* dst_sizes = res.get_sizes();

    for (size_t idx = start; idx < end; idx++) {
      bsg_attr_remote scalar_dst* dst_data = res_data + idx % dst_sizes[1] * dst_strides[1] + idx / dst_sizes[1] * dst_strides[0];
      bsg_attr_remote scalar_src* src_data = input_data + idx % src_sizes[1] * src_strides[1] + idx / src_sizes[1] * src_strides[0];

      for (size_t inner = 0; inner < res.dim(2); inner++) {
        scalar_src input_dp_0 = *(src_data);
        bsg_attr_remote scalar_dst* res_dp_0 = (dst_data);
        dst_data += dst_strides[2];
        src_data += src_strides[2];

        *res_dp_0 = functor(input_dp_0);
      }
    }
  } else {
    //-----------------------------
    // iterating over all elementes
    //-----------------------------
    hb_range range;
    calc_range(&range, res.numel());
    size_t start = range.start;
    size_t end   = range.end;

    for (size_t idx = start; idx < end; idx++) {
      bsg_attr_remote scalar_dst* res_dp = (res_data + offset_calc(idx, res));
      bsg_attr_remote scalar_src* input_dp = (input_data + offset_calc(idx, input));
      *res_dp = functor(*input_dp);
    }
  }
}

// =========================================================
// HB for
// =========================================================
// functor takes in current index

template <class FetchFunctor>
inline void hb_for(size_t numel, FetchFunctor functor) {
  //--------------------------------------
  // calculate start and end for this tile
  //--------------------------------------
  size_t start = 0;
  size_t end = numel;
  //-----------------
  // loop
  //----------------
  for (size_t i = start; i < end; i++) {
    functor(i);
  }
}

// =========================================================
// HB tile for
// =========================================================
// functor takes in current index

template <class FetchFunctor>
inline void hb_tiled_for(size_t numel, FetchFunctor functor) {
  //--------------------------------------
  // calculate start and end for this tile
  //--------------------------------------
  hb_range range;
  calc_range(&range, numel);
  size_t start = range.start;
  size_t end   = range.end;

  //-----------------
  // loop
  //----------------
  for (size_t i = start; i < end; i++) {
    functor(i);
  }
}

template <class FetchFunctor>
inline void hb_tiled_for(size_t tg_size, size_t numel, FetchFunctor functor) {
  //--------------------------------------
  // calculate start and end for this tile
  //--------------------------------------
  hb_range range;
  calc_range(&range, numel, tg_size);
  size_t start = range.start;
  size_t end   = range.end;

  //-----------------
  // loop
  //----------------
  for (size_t i = start; i < end; i++) {
    functor(i);
  }
}

template <class FetchFunctor>
inline void hb_tiled_for(size_t tg_size,
                         FetchFunctor functor,
                         size_t N, size_t M) {
  //--------------------------------------
  // calculate start and end for this tile
  //--------------------------------------
  hb_range range;
  calc_range(&range, N * M, tg_size);
  size_t start = range.start;
  size_t end   = range.end;

  //-----------------
  // loop
  //----------------
  for (size_t i = start; i < end; i++) {
    size_t b = (i / M) % N;
    size_t a = i % M;
    functor(b, a);
  }
}

template <class FetchFunctor>
inline void hb_tiled_for(size_t tg_size,
                         FetchFunctor functor,
                         size_t O, size_t N, size_t M) {
  //--------------------------------------
  // calculate start and end for this tile
  //--------------------------------------
  hb_range range;
  calc_range(&range, O * N * M, tg_size);
  size_t start = range.start;
  size_t end   = range.end;

  //-----------------
  // loop
  //----------------
  for (size_t i = start; i < end; i++) {
    size_t c = (i / (N * M)) % O;
    size_t b = (i / M) % N;
    size_t a = i % M;
    functor(c, b, a);
  }
}

template <class FetchFunctor>
inline void hb_tiled_for(size_t tg_size,
                         FetchFunctor functor,
                         size_t P, size_t O, size_t N, size_t M) {
  //--------------------------------------
  // calculate start and end for this tile
  //--------------------------------------
  hb_range range;
  calc_range(&range, P * O * N * M, tg_size);
  size_t start = range.start;
  size_t end   = range.end;

  //-----------------
  // loop
  //----------------
  for (size_t i = start; i < end; i++) {
    size_t d = (i / (O * N * M)) % P;
    size_t c = (i / (N * M)) % O;
    size_t b = (i / M) % N;
    size_t a = i % M;
    functor(d, c, b, a);
  }
}

// =========================================================
// HB tile range
// =========================================================
// functor takes in current index

template <class FetchFunctor>
inline void hb_tiled_range(size_t numel, FetchFunctor functor) {
  //--------------------------------------
  // calculate start and end for this tile
  //--------------------------------------
  hb_range range;
  calc_range(&range, numel);
  size_t start = range.start;
  size_t end   = range.end;

  //-----------------
  // range
  //----------------
  functor(start, end);
}


template <class FetchFunctor>
inline void hb_tiled_for_hack(size_t numel, FetchFunctor functor) {
  //--------------------------------------
  // calculate start and end for this tile
  //--------------------------------------
  for (size_t i = __bsg_id; i < numel; i += (bsg_tiles_X * bsg_tiles_Y)) {
    functor(i);
  }
}

#endif
