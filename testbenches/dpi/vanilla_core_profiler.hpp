// This header file defines a C++ API that wraps the System Verilog
// DPI provided by vanilla_core_profiler.v in
// bsg_manycore/testbenches/common/v/
#ifndef __BSG_NONSYNTH_DPI_VANILLA_CORE_PROFILER
#define __BSG_NONSYNTH_DPI_VANILLA_CORE_PROFILER
#include <bsg_nonsynth_dpi.hpp>
#include <bsg_nonsynth_dpi_errno.hpp>
#include <string>

// These are DPI functions provided by SystemVerilog compiler. If they
// are not found at link time, compilation will fail. See the
// corresponding function declarations in vanilla_core_profiler.v for
// additional information.
extern "C" {
        extern void bsg_dpi_init();
        extern void bsg_dpi_fini();
        extern unsigned char bsg_dpi_vanilla_core_profiler_is_window();
        extern void bsg_dpi_vanilla_core_profiler_get_instr_count(int itype, int *count);
}

namespace bsg_nonsynth_dpi{
        /*
         * dpi_vanilla_core_profiler wraps an instantiation of
         * vanilla_core_profiler in a verilog design and provides
         * C/C++-like functionality to the DPI interface.
         *
         * Functions:
         *   dpi_vanilla_core_profiler: Constructor
         *   get_instr_count: Get number of instructions executed for a particular class of instructions
         */
        class dpi_vanilla_core_profiler : public dpi_base{
        public:

                /**
                 * Return an instance of dpi_vanilla_core_profiler
                 *
                 * @param[in] hierarchy The path to the
                 *   vanilla_core_profiler instance in the design hierarchy
                 *
                 * @return a valid instance of dpi_vanilla_core_profiler
                 */
                dpi_vanilla_core_profiler(const std::string &hierarchy)
                        : dpi_base(hierarchy)
                {
                }
                
                /**
                 * Get the number of instructions executed for a
                 * particular class of instructions
                 *
                 * @param[in] itype an integer representing the class
                 * of instructions to query. Three types are
                 * supported: 0 (float, for floating point arithmetic
                 * operations), 1, (integer, for integer arithmetic
                 * operations) and 2 (for all instructions, including
                 * control flow).
                 *
                 * @param[out] count Number of instructions executed
                 *
                 * @return BSG_NONSYNTH_DPI_SUCCESS on success,
                 * BSG_NONSYNTH_DPI_NOT_WINDOW when not in valid clock
                 * window.
                 */
                int get_instr_count(int itype, int *count){
                        prev = svSetScope(scope);
                        if(!bsg_dpi_vanilla_core_profiler_is_window()){
                                svSetScope(prev);
                                return BSG_NONSYNTH_DPI_NOT_WINDOW;
                        }

                        bsg_dpi_vanilla_core_profiler_get_instr_count(itype, count);

                        svSetScope(prev);
                        return BSG_NONSYNTH_DPI_SUCCESS;
                }

        };
}

#endif // __BSG_NONSYNTH_DPI_VANILLA_CORE_PROFILER
