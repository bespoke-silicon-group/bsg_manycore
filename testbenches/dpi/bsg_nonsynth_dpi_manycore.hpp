#ifndef __BSG_NONSYNTH_DPI_MANYCORE
#define __BSG_NONSYNTH_DPI_MANYCORE
#include <bsg_nonsynth_dpi.hpp>
#include <bsg_nonsynth_dpi_fifo.hpp>
#include <bsg_nonsynth_dpi_errno.hpp>
#include <bsg_nonsynth_dpi_rom.hpp>
#include <svdpi.h>
#include <cstring>
#include <cstdint>
#include <xmmintrin.h>
extern "C" {
        extern unsigned char bsg_dpi_credits_is_window();
        extern int bsg_dpi_credits_get_cur();
        extern int bsg_dpi_credits_get_max();
}

namespace bsg_nonsynth_dpi{
        template <unsigned int N>
        class dpi_manycore : public dpi_base{
                dpi_to_fifo<__m128i> d2f_req;
                dpi_from_fifo<__m128i> f2d_rsp;
                dpi_from_fifo<__m128i> f2d_req;
                int max_credits, cur_credits = 0;
        public:
                dpi_rom<unsigned int, N> config;
                dpi_manycore(std::string &hierarchy)
                        : dpi_base(hierarchy),
                          d2f_req(hierarchy + ".d2f_req_i"),
                          f2d_rsp(hierarchy + ".f2d_rsp_i"),
                          f2d_req(hierarchy + ".f2d_req_i"), 
                          config(hierarchy + ".rom")
                {

                        prev = svSetScope(scope);
                        max_credits = bsg_dpi_credits_get_max();
                        svSetScope(prev);
                }

                int get_credits(int& credits){
                        prev = svSetScope(scope);
                        if(!bsg_dpi_credits_is_window()){
                                svSetScope(prev);
                                return BSG_NONSYNTH_DPI_NOT_WINDOW;
                        }

                        credits = bsg_dpi_credits_get_cur();
                        svSetScope(prev);
                        return BSG_NONSYNTH_DPI_SUCCESS;
                }

                int tx_req(const __m128i &data){
                        int res = BSG_NONSYNTH_DPI_SUCCESS;
                        // Get credits checks for window
                        if(!cur_credits)
                                res = get_credits(cur_credits);

                        if(res != BSG_NONSYNTH_DPI_SUCCESS)
                                return res;

                        if(cur_credits == 0)
                                return BSG_NONSYNTH_DPI_NO_CREDITS;

                        if(cur_credits < 0)
                                return BSG_NONSYNTH_DPI_INVALID;

                        if(cur_credits)
                                res = d2f_req.try_tx(data);

                        if(res == BSG_NONSYNTH_DPI_SUCCESS)
                                cur_credits--;

                        return res;
                }

                int rx_rsp(__m128i &data){
                        return f2d_rsp.try_rx(data);
                }

                bool rx_req(__m128i &data){ 
                        return f2d_req.try_rx(data);
                }

        };
        
        
}
#endif
