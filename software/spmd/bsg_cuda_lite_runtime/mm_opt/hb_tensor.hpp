//====================================================================
// Tensor Data Structures
// 03/09/2020 Bandhav Veluri and Lin Cheng (lc873@cornell.edu)
//====================================================================

#ifndef _HB_TENSOR_HPP
#define _HB_TENSOR_HPP

#include <bsg_manycore.h>
#include <hb_assert.hpp>
#include <hb_common.hpp>

#define DEFAULT_STRIDES 5

// =========================================================
// Device Tensor structs
//
// These structs are used by the device to move tensors (and
// as a special case, vectors) back and forth the host. As a
// these structs have to maintain the exact same memory layout
// to those on the host. A consequence of that is these have
// to be pure C struct.
// =========================================================

typedef struct {
  uint32_t N;
  uint32_t dims;

#ifdef HB_EMUL
  uint64_t strides;
  uint64_t sizes;
  uint64_t data;
#else
  uint32_t strides;
  uint32_t sizes;
  uint32_t data;
#endif

// Info about storage objects
#ifdef HB_ENABLE_KERNEL_LOG
  void* storage_head;
  uint32_t storage_numel;
#endif
} hb_tensor_t;

typedef struct {
  uint32_t N;
#ifdef HB_EMUL
  uint64_t data;
#else
  uint32_t data;
#endif
} hb_vector_t;

// =========================================================
// Device Tensor classes
//
// Wrapper classes around device tensor structs to provide
// convenience operations. This runs on a tiny RISC-V processor
// on the device, so be careful about using dynamic memory
// allocation.
// =========================================================

template<typename DT, typename IT>
class HBTensorImpl {
  private:
    uint32_t N;
    uint32_t dims;
    IT* strides;
    IT* sizes;
    DT* data;

  public:
    HBTensorImpl(uint32_t N, uint32_t dims, IT* strides,
                 IT* sizes, DT* data) :
      N(N),
      dims(dims),
      strides(strides),
      sizes(sizes),
      data(data) {
        // WAW HW bug seems to be triggered on a non-bloacking load to
        // the register holding `sizes` in various kernels. This fix
        // adds a RAW dependedncy on that register, blocking the load.
        HB_FIX_WAW_HAZARD(sizes);
      }

    bsg_attr_remote char* data_ptr() {
      return (bsg_attr_remote char*)data;
    }

    IT* get_strides() {
      return strides;
    }

    IT* get_sizes() {
      return sizes;
    }

    uint32_t numel() {
      return N;
    }

    uint32_t dim(uint32_t d) {
      //hb_assert_msg(d < dims,
      //              "error: dimesnion must be less than %d\n",
      //              dims);
      return sizes[d];
    }

    uint32_t ndim() {
      return dims;
    }

    template<typename ...T>
    uint32_t offset(T... indices) {
      uint32_t index_arr[] = {((uint32_t)indices)...};
      const uint32_t n = sizeof(index_arr) / sizeof(index_arr[0]);

      uint32_t offset = 0;
      bsg_unroll(DEFAULT_STRIDES) for(int i=0; i< n; ++i) {
        offset += index_arr[i] * strides[i];
      }

      return offset;
    }

    // Special case where we want linear, 0-d
    // and 1-d tensor indexing.
    //
    // XXX: The tensor has to be contiguous if
    // it's >1-d tensor.
    DT& operator()(uint32_t index) {
      //hb_assert_msg(index < N,
      //              "error: N=%d but accessed %d\n",
      //              N, index);
      if(dims != 1) {
        return data[index];
      } else {
        // Explicitly calculate data index to handle
        // non-contiguous 1-d tensors.
        return data[index * strides[0]];
      }
    }

    DT& operator()(uint32_t index0, uint32_t index1) {
      return data[index0 * strides[0]
                  + index1 * strides[1]];
    }

    DT& operator()(uint32_t index0, uint32_t index1, uint32_t index2) {
      return data[index0 * strides[0]
                  + index1 * strides[1]
                  + index2 * strides[2]];
    }

    DT& operator()(uint32_t index0, uint32_t index1, uint32_t index2, uint32_t index3) {
      return data[index0 * strides[0]
                  + index1 * strides[1]
                  + index2 * strides[2]
                  + index3 * strides[3]];
    }
};

template <typename DT, int32_t dims=-1>
class HBTensor : public HBTensorImpl<bsg_attr_remote DT, uint32_t> {
  private:
    uint32_t strides[dims];
    uint32_t sizes[dims];

  public:
    HBTensor(hb_tensor_t* t) :
      HBTensorImpl<bsg_attr_remote DT, uint32_t>(
        t->N,
        (uint32_t) dims,
        strides,
        sizes,
        (bsg_attr_remote DT*) ((intptr_t) t->data)
      ) {
        //hb_assert_msg(
        //  t->dims == dims,
        //  "error: HBTensor dims don't match offloaed tensor dims");

        uint32_t* strides_remote = (uint32_t*) ((intptr_t) t->strides);
        uint32_t* sizes_remote = (uint32_t*) ((intptr_t) t->sizes);

        // Move strides and sizes to scratchpad
        for(int i=0; i<dims; ++i) {
          strides[i] = strides_remote[i];
          sizes[i] = sizes_remote[i];
        }
      }
};

template <typename DT>
class HBTensor<DT, -1> : public HBTensorImpl<bsg_attr_remote DT, uint32_t> {
  private:
    uint32_t strides[DEFAULT_STRIDES];
    uint32_t sizes[DEFAULT_STRIDES];

  public:
    HBTensor(hb_tensor_t* t) :
      HBTensorImpl<bsg_attr_remote DT, uint32_t>(
        t->N,
        t->dims,
        strides,
        sizes,
        (bsg_attr_remote DT*) ((intptr_t) t->data)
      ) {
        //hb_assert_msg(
        //  t->dims <= DEFAULT_STRIDES,
        //  "error: tensor dims is too large");

        uint32_t* strides_remote = (uint32_t*) ((intptr_t) t->strides);
        uint32_t* sizes_remote = (uint32_t*) ((intptr_t) t->sizes);

        // Move strides and sizes to scratchpad
        for(int i=0; i<t->dims; ++i) {
          strides[i] = strides_remote[i];
          sizes[i] = sizes_remote[i];
        }
      }
};

template <typename DT, uint32_t N, uint32_t C, uint32_t H, uint32_t W>
class HBTensor4d {
  private:
    const uint32_t numel = N * C * H * W;
    const uint32_t strides[4] = {
      numel / N, numel / (N*C), numel / (N*C*H), 1
    };
    DT* data;

  public:
    HBTensor4d(hb_tensor_t* t) :
      data((DT*) ((intptr_t) t->data)) {}

    uint32_t offset(uint32_t n, uint32_t c, uint32_t h, uint32_t w) {
      return strides[0]*n + strides[1]*c + strides[2]*h + w;
    }

    char* data_ptr() {
      return (char*)data;
    }

    DT& operator()(uint32_t n, uint32_t c, uint32_t h, uint32_t w) {
      uint32_t offset = strides[0]*n + strides[1]*c + strides[2]*h + w;
      return data[offset];
    }

    void init(DT val) {
      for(int i = 0; i < N; ++i) {
        data[i] = val;
      }
    }
};

template<typename T>
class HBVector {
  private:
    uint32_t N;
    T* data;

  public:
    HBVector(hb_vector_t* v) :
      N(v->N), data((T*) ((intptr_t) v->data)) {}

    uint32_t numel() {
      return N;
    }

    T& operator[](uint32_t i) {
      return data[i];
    }
};

#endif // _HB_TENSOR_HPP
