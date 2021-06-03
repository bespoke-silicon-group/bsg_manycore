#include <stdint.h>
#include <bp_utils.h>

// Address definitions
const uint64_t mc_vcache_mmio = 0b100000000000000000000000000000000000000000;
const uint64_t mc_tile_mmio   = 0b110000000000000000000000000000000000000000;
const uint64_t mc_host_fifo   = 0b111000000000000000000000000000000000000000;

const uint64_t mc_host_x_coord = ((0 << HB_MC_POD_X_SUBCOORD_WIDTH) | 0) << (HB_MC_TILE_EPA_WIDTH + 2);
const uint64_t mc_host_y_coord = ((1 << HB_MC_POD_Y_SUBCOORD_WIDTH) | 0) << (HB_MC_X_COORD_WIDTH + HB_MC_TILE_EPA_WIDTH + 2);

// Using the tile MMIO interface to communicate with the host as though it was a compute tile
// We don't have to shift the EPA by 2 bits since, the monitor logic takes care of that
uint64_t *mc_finish_addr          = (uint64_t *) (mc_tile_mmio | mc_host_y_coord | mc_host_x_coord | (HB_MC_HOST_FINISH_EPA));
uint64_t *mc_time_addr            = (uint64_t *) (mc_tile_mmio | mc_host_y_coord | mc_host_x_coord | (HB_MC_HOST_TIME_EPA));
uint64_t *mc_fail_addr            = (uint64_t *) (mc_tile_mmio | mc_host_y_coord | mc_host_x_coord | (HB_MC_HOST_FAIL_EPA));
uint64_t *mc_stdout_addr          = (uint64_t *) (mc_tile_mmio | mc_host_y_coord | mc_host_x_coord | (HB_MC_HOST_STDOUT_EPA));
uint64_t *mc_stderr_addr          = (uint64_t *) (mc_tile_mmio | mc_host_y_coord | mc_host_x_coord | (HB_MC_HOST_STDERR_EPA));
uint64_t *mc_branch_trace_addr    = (uint64_t *) (mc_tile_mmio | mc_host_y_coord | mc_host_x_coord | (HB_MC_HOST_BRANCH_TRACE_EPA));
uint64_t *mc_print_stat_addr      = (uint64_t *) (mc_tile_mmio | mc_host_y_coord | mc_host_x_coord | (HB_MC_HOST_PRINT_STAT_EPA));

volatile uint64_t *mc_link_bp_req_fifo_addr     = (uint64_t *) (BRIDGE_CSR_BP_REQ_FIFO_ADDR     | mc_host_fifo);
volatile uint64_t *mc_link_bp_req_credits_addr  = (uint64_t *) (BRIDGE_CSR_BP_REQ_CREDITS_ADDR  | mc_host_fifo);
volatile uint64_t *mc_link_bp_resp_fifo_addr    = (uint64_t *) (BRIDGE_CSR_MC_RESP_FIFO_ADDR    | mc_host_fifo);
volatile uint64_t *mc_link_bp_resp_entries_addr = (uint64_t *) (BRIDGE_CSR_MC_RESP_ENTRIES_ADDR | mc_host_fifo);
volatile uint64_t *mc_link_mc_req_fifo_addr     = (uint64_t *) (BRIDGE_CSR_MC_REQ_FIFO_ADDR     | mc_host_fifo);
volatile uint64_t *mc_link_mc_req_entries_addr  = (uint64_t *) (BRIDGE_CSR_MC_REQ_ENTRIES_ADDR  | mc_host_fifo);
volatile uint64_t *mc_link_rom_start_addr       = (uint64_t *) (BRIDGE_CSR_MC_ROM_START_ADDR    | mc_host_fifo);
volatile uint64_t *mc_link_rom_end_addr         = (uint64_t *) (BRIDGE_CSR_MC_ROM_END_ADDR      | mc_host_fifo);

volatile uint64_t *hio_mask_addr = (uint64_t *) (0x001c | BP_CFG_OFFSET);

void bp_finish(uint8_t code) {
  if (!code) {
    *mc_finish_addr = 0;
  } else {
    *mc_fail_addr = code;
  }
}

void bp_hprint(uint8_t hex) {
  *mc_stdout_addr = ('0' + hex);
}

void bp_cprint(uint8_t ch) {
  *mc_stdout_addr = ch;
}

uint64_t bp_get_hart() {
    uint64_t core_id;
    __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);
    return core_id;
}

