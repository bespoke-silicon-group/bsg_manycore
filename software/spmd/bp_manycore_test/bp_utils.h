#ifndef BP_UTILS_H
#define BP_UTILS_H

#include <stdint.h>

// Machine parameters
#define HB_MC_TILE_EPA_WIDTH 18
#define HB_MC_MAX_EPA_WIDTH 28
#define HB_MC_POD_X_COORD_WIDTH 3
#define HB_MC_POD_Y_COORD_WIDTH 4
#define HB_MC_POD_X_SUBCOORD_WIDTH 4
#define HB_MC_POD_Y_SUBCOORD_WIDTH 3
#define HB_MC_X_COORD_WIDTH HB_MC_POD_X_COORD_WIDTH + HB_MC_POD_X_SUBCOORD_WIDTH
#define HB_MC_Y_COORD_WIDTH HB_MC_POD_Y_COORD_WIDTH + HB_MC_POD_Y_SUBCOORD_WIDTH
#define HB_MC_IO_MAX_EP_CREDITS 16

// Host EPAs
#define HB_MC_HOST_FINISH_EPA 0xead0
#define HB_MC_HOST_TIME_EPA 0xead4
#define HB_MC_HOST_FAIL_EPA 0xead8
#define HB_MC_HOST_STDOUT_EPA 0xeadc
#define HB_MC_HOST_STDERR_EPA 0xeae0
#define HB_MC_HOST_BRANCH_TRACE_EPA 0xeae4
#define HB_MC_HOST_PRINT_STAT_EPA 0xea0c

// Bridge CSR memory map
#define BRIDGE_CSR_BP_REQ_FIFO_ADDR 0x1000
#define BRIDGE_CSR_BP_REQ_CREDITS_ADDR 0x2000
#define BRIDGE_CSR_MC_RESP_FIFO_ADDR 0x3000
#define BRIDGE_CSR_MC_RESP_ENTRIES_ADDR 0x4000
#define BRIDGE_CSR_MC_REQ_FIFO_ADDR 0x5000
#define BRIDGE_CSR_MC_REQ_ENTRIES_ADDR 0x6000
#define BRIDGE_CSR_MC_ROM_START_ADDR 0x7000
#define BRIDGE_CSR_MC_ROM_END_ADDR 0x7fff

// Config bus addresses
#define BP_CFG_OFFSET 0x200000
extern volatile uint64_t *hio_mask_addr;

// Address declarations
extern const uint64_t mc_vcache_mmio;
extern const uint64_t mc_tile_mmio;
extern const uint64_t mc_host_fifo;

// Addresses below need to be declared as 64 bits to MMIO into the manycore, but all of them do only 32-bit loads and stores
// Host addresses
extern const uint64_t mc_host_x_coord;
extern const uint64_t mc_host_y_coord;

extern uint8_t *mc_finish_addr;
extern uint8_t *mc_time_addr;
extern uint8_t *mc_fail_addr;
extern uint8_t *mc_stdout_addr;
extern uint8_t *mc_stderr_addr;
extern uint8_t *mc_branch_trace_addr;
extern uint8_t *mc_print_stat_addr;

// Bridge CSR addresses
extern volatile uint64_t *mc_link_bp_req_fifo_addr;
extern volatile uint64_t *mc_link_bp_req_credits_addr;
extern volatile uint64_t *mc_link_bp_resp_fifo_addr;
extern volatile uint64_t *mc_link_bp_resp_entries_addr;
extern volatile uint64_t *mc_link_mc_req_fifo_addr;
extern volatile uint64_t *mc_link_mc_req_entries_addr;
extern volatile uint64_t *mc_link_rom_start_addr;
extern volatile uint64_t *mc_link_rom_end_addr;

// Manycore packet interface
typedef struct response_packet {
        uint8_t   x_dst; //!< x coordinate of the requester
        uint8_t   y_dst; //!< y coordinate of the requester
        uint8_t   load_id; //!< read response id
        uint32_t  data; //!< packet's payload data
        uint8_t   op;    //!< opcode
        uint8_t   reserved[8];
} __attribute__((packed)) hb_mc_response_packet_t;

typedef struct request_packet {
        uint8_t  x_dst; //!< x coordinate of the responder
        uint8_t  y_dst; //!< y coordinate of the responder
        uint8_t  x_src; //!< x coordinate of the requester
        uint8_t  y_src; //!< y coordinate of the requester
        uint32_t data;  //!< packet's payload data
        uint8_t  reg_id; //!< 5-bit id for load or amo
        uint8_t  op_v2;  //!< 4-bit byte mask
        uint32_t addr;  //!< address field (EPA)
        uint8_t  reserved[2];
}  __attribute__((packed)) hb_mc_request_packet_t;

typedef union packet {
        hb_mc_request_packet_t request; /**/
        hb_mc_response_packet_t response; /* from the Hammerblade Manycore */
        uint32_t words[4];
} hb_mc_packet_t;

uint64_t bp_get_hart();

void bp_hprint(uint8_t hex);

void bp_cprint(uint8_t ch);

void bp_finish(uint8_t code);

#endif