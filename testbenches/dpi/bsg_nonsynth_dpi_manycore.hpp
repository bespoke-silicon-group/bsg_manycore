// This header file defines a C++ API that wraps the System Verilog
// DPI provided by bsg_nonsynth_dpi_manycore.v
#ifndef __BSG_NONSYNTH_DPI_MANYCORE
#define __BSG_NONSYNTH_DPI_MANYCORE
#include <bsg_nonsynth_dpi.hpp>
#include <bsg_nonsynth_dpi_fifo.hpp>
#include <bsg_nonsynth_dpi_errno.hpp>
#include <bsg_nonsynth_dpi_rom.hpp>
#include <svdpi.h>
#include <cstring>
#include <cstdint>
// We use __m128i so that we can pass a 128-bit type between Verilog
// and C.
#include <xmmintrin.h>

// These are DPI functions provided by SystemVerilog compiler. If they
// are not found at link time, compilation will fail. See the
// corresponding function declarations in bsg_nonsynth_dpi_manycore.v
// for additional information.
extern "C" {
        extern unsigned char bsg_dpi_is_window();
        extern unsigned char bsg_dpi_reset_is_done();
        extern unsigned char bsg_dpi_tx_is_vacant();
        extern int bsg_dpi_credits_get_cur();
        extern int bsg_dpi_credits_get_max();
}

namespace bsg_nonsynth_dpi{
        /*
         * dpi_manycore wraps an instantiation of
         * bsg_nonsynth_dpi_manycore in a verilog design and provides
         * C/C++-like functionality to the DPI interface.
         *
         * Template Parameters:
         *   N: Number of ROM elements in the Manycore design
         *
         * Functions:
         *   dpi_manycore: Constructor
         *   get_credits: Get number of available transmit credits
         *   tx_req: Transmit a request packet
         *   rx_rsp: Receive a response packet
         *   rx_req: Receive a request packet
         */
        template <unsigned int N>
        class dpi_manycore : public dpi_base{
                // DPI To Fifo (Request) Interface Object
                dpi_to_fifo<__m128i> d2f_req;
                // Fifo to DPI (Response) Interface Object
                dpi_from_fifo<__m128i> f2d_rsp;
                // Fifo to DPI (Request) Interface Object
                dpi_from_fifo<__m128i> f2d_req;
                // Maximum available credits (used for fences)
                int max_credits = -1;
                // Current available credits (used for flow control, and fences)
                int cur_credits = 0;
                bool reset_done = false;
        public:
                // Stores configuration data for the manycore DUT.
                // Each entry is an unsigned 32-bit value
                dpi_rom<unsigned int, N> config;

                /**
                 * Return an instance of dpi_manycore
                 *
                 * @param[in] hierarchy The path to the
                 *   bsg_nonsynth_dpi_manycore instance in the design hierarchy
                 *
                 * @return a valid instance of dpi_manycore
                 */
                dpi_manycore(const std::string &hierarchy)
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

                /**
                 * Get the number of manycore credits currently
                 * available to the bsg_nonsynth_dpi_manycore
                 * instance.
                 *
                 * @param[out] credits  The number of manycore network credits available
                 *
                 * @return BSG_NONSYNTH_DPI_SUCCESS on success,
                 * BSG_NONSYNTH_DPI_NOT_WINDOW when not in valid clock
                 * window.
                 */
                int get_credits(int& credits){
                        int res = BSG_NONSYNTH_DPI_SUCCESS;
                        prev = svSetScope(scope);
                        if(!reset_done)
                                res = reset_is_done(reset_done);

                        if(res != BSG_NONSYNTH_DPI_SUCCESS){
                                svSetScope(prev);
                                return res;
                        }

                        if(!bsg_dpi_is_window()){
                                svSetScope(prev);
                                return BSG_NONSYNTH_DPI_NOT_WINDOW;
                        }

                        credits = bsg_dpi_credits_get_cur();
                        svSetScope(prev);
                        return BSG_NONSYNTH_DPI_SUCCESS;
                }

                /**
                 * Determines if the transmit fifo is vacant
                 *
                 * @param[out] vacant Boolean value, true if transmit
                 * fifo is empty (vacant)
                 *
                 * @return BSG_NONSYNTH_DPI_SUCCESS on success,
                 * BSG_NONSYNTH_DPI_NOT_WINDOW when not in valid clock
                 * window.
                 */
                int tx_is_vacant(bool& vacant){
                        prev = svSetScope(scope);
                        if(!bsg_dpi_is_window()){
                                svSetScope(prev);
                                return BSG_NONSYNTH_DPI_NOT_WINDOW;
                        }

                        vacant = bsg_dpi_tx_is_vacant();
                        svSetScope(prev);
                        return BSG_NONSYNTH_DPI_SUCCESS;
                }

                /**
                 * Determines if reset is done
                 *
                 * @param[out] done Boolean value, true if reset is
                 * done
                 *
                 * @return BSG_NONSYNTH_DPI_SUCCESS on success,
                 * BSG_NONSYNTH_DPI_BUSY when not done
                 * window.
                 */
                int reset_is_done(bool& done){
                        prev = svSetScope(scope);
                        if(!bsg_dpi_is_window()){
                                svSetScope(prev);
                                return BSG_NONSYNTH_DPI_NOT_WINDOW;
                        }

                        done = bsg_dpi_reset_is_done();
                        if(!done){
                                return BSG_NONSYNTH_DPI_BUSY;
                                svSetScope(prev);
                        }

                        svSetScope(prev);
                        return BSG_NONSYNTH_DPI_SUCCESS;
                }


                /**
                 * Transmit a request packet onto the manycore network
                 * using the DPI interface.
                 *
                 * @param[in] data   Padded packet data to
                 *   transmit. (The module will handle formatting)
                 *
                 * @return BSG_NONSYNTH_DPI_SUCCESS on success
                 *         (Recoverable Errors)
                 *         BSG_NONSYNTH_DPI_BUSY when reset is not done
                 *         BSG_NONSYNTH_DPI_NOT_WINDOW when not in valid clock window
                 *         BSG_NONSYNTH_DPI_NO_CREDITS when no transmit credits are available
                 *         BSG_NONSYNTH_DPI_NOT_READY when the packet was not transmitted (call again next cycle)
                 */
                int tx_req(const __m128i &data){
                        int res = BSG_NONSYNTH_DPI_SUCCESS;

                        if(!reset_done)
                                res = reset_is_done(reset_done);

                        if(res != BSG_NONSYNTH_DPI_SUCCESS)
                                return res;

                        // Get credits checks for valid window
                        if(!cur_credits)
                                res = get_credits(cur_credits);

                        if(res != BSG_NONSYNTH_DPI_SUCCESS)
                                return res;

                        if(cur_credits == 0)
                                return BSG_NONSYNTH_DPI_NO_CREDITS;

                        // try_tx checks for valid window
                        if(cur_credits)
                                res = d2f_req.try_tx(data);

                        if(res == BSG_NONSYNTH_DPI_SUCCESS)
                                cur_credits--;

                        return res;
                }

                /**
                 * Receive a response packet (if available) using the DPI interface.
                 *
                 * @param[out] data   Padded, received packet data.
                 *   (The verilog module will insert padding)
                 *
                 * @return BSG_NONSYNTH_DPI_SUCCESS on success
                 *         (Recoverable Errors)
                 *         BSG_NONSYNTH_DPI_BUSY when reset is not done
                 *         BSG_NONSYNTH_DPI_NOT_WINDOW when not in valid clock window
                 *         BSG_NONSYNTH_DPI_NOT_VALID when no packet is available
                 */
                int rx_rsp(__m128i &data){
                        int res = BSG_NONSYNTH_DPI_SUCCESS;
                        if(!reset_done)
                                res = reset_is_done(reset_done);

                        if(res != BSG_NONSYNTH_DPI_SUCCESS)
                                return res;

                        return f2d_rsp.try_rx(data);
                }

                /**
                 * Receive a request packet (if available) using the DPI interface.
                 *
                 * @param[out] data   Padded, received packet data.
                 *   (The verilog module will insert padding)
                 *
                 * @return BSG_NONSYNTH_DPI_SUCCESS on success
                 *         (Recoverable Errors)
                 *         BSG_NONSYNTH_DPI_BUSY when reset is not done
                 *         BSG_NONSYNTH_DPI_NOT_WINDOW when not in valid clock window
                 *         BSG_NONSYNTH_DPI_NOT_VALID when no packet is available
                 */
                int rx_req(__m128i &data){
                        int res = BSG_NONSYNTH_DPI_SUCCESS;
                        if(!reset_done)
                                res = reset_is_done(reset_done);

                        if(res != BSG_NONSYNTH_DPI_SUCCESS)
                                return res;

                        return f2d_req.try_rx(data);
                }

        };
}
#endif
