#ifndef __BSG_NONSYNTH_DPI_MANYCORE
#define __BSG_NONSYNTH_DPI_MANYCORE
#include <bsg_nonsynth_dpi.hpp>
#include <bsg_nonsynth_dpi_fifo.hpp>
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

                bool try_get_credits(int& credits){
                        prev = svSetScope(scope);
                        if(!bsg_dpi_credits_is_window())
                                return false;

                        credits = bsg_dpi_credits_get_cur();
                        svSetScope(prev);
                        return true;
                }

                bool try_tx_req(const __m128i &data){
                        bool res = false;
                        if(!d2f_req.is_window()){
                                return res;
                        }
                        if(!cur_credits){
                                prev = svSetScope(scope);
                                cur_credits = bsg_dpi_credits_get_cur();
                                svSetScope(prev);
                        } 
                        if(cur_credits){
                                res = d2f_req.tx(data);
                                if(res)
                                        cur_credits--;
                        }
                        return res;
                }

                bool try_rx_rsp(__m128i &data){
                        if(!f2d_rsp.is_window())
                                return false;

                        return f2d_rsp.rx(data);
                }

                bool try_rx_req(__m128i &data){ 
                       if(!f2d_req.is_window())
                                return false;

                        return f2d_req.rx(data);
                }

        };
        
        
}
#endif
