//====================================================================
// main.S
// 03/29/2017, shawnless.xie@gmail.com
//====================================================================
// This is the runtime for manycore served as smart on chip memory.


//====================================================================
// The regsiter allocation

#define SM_GO_REG               x2
#define SM_OUTPUT_PTR_REG       x4
#define SM_DATA_LEN_REG         x5
#define SM_DATA_START_REG       x6

#define TMP_PTR_REG             x16
#define TMP_DATA_REG            x17
#define TMP_LOOP_IND_REG        x18
#define TMP_IMM4_REG            x19

//====================================================================
// Start of the real program
.text 
.global sm_start; sm_start:
//------------------------------
//if sm_go is zero, we loop here
1:
lw      SM_GO_REG          ,sm_go                   ;
nop                                                 ;
beqz    SM_GO_REG          ,1b                      ;

//------------------------------
//setup all the parameters
li      TMP_IMM4_REG       ,0x4                     ;
mv      TMP_LOOP_IND_REG   ,x0                      ;
lw      TMP_PTR_REG        ,sm_data_start           ;

lw      SM_DATA_LEN_REG    ,sm_data_len             ;
lw      SM_OUTPUT_PTR_REG  ,output_ptr              ;

//------------------------------
//the loop body which will store the data
.global loop_start; loop_start:
1:
lw      TMP_DATA_REG       ,0(TMP_PTR_REG)                  ;
add     TMP_LOOP_IND_REG   ,TMP_LOOP_IND_REG, TMP_IMM4_REG  ;
sw      TMP_DATA_REG       ,0(SM_OUTPUT_PTR_REG)            ; 
bge     TMP_LOOP_IND_REG   ,SM_DATA_LEN_REG,     1b         ;
.global loop_end; loop_end:

//------------------------------
//signal next  tile should start
fence                                                       ;
//clear the sm_go signal 
sw      x0                 ,sm_go   , SM_GO_REG             ;

lw      TMP_PTR_REG        ,sm_go_ptr                       ;
li      TMP_DATA_REG       ,0x1                             ;
sw      TMP_DATA_REG       ,0(TMP_PTR_REG)                  ; 

j                          sm_start                         ;

//====================================================================
//Data section starts
.data
//The Rocket will access the data through a sm_data_struct, in which all
//members should declared as in follow order
.global sm_data_struct; sm_data_struct:

//The the output io pointer
.global output_ptr; output_ptr:
.int 0x0

//The data indicates should we start a new around
.global sm_go; sm_go:
.int 0x0

//The pointer of next tile's sm_go
.global sm_go_ptr; sm_go_ptr:
.int 0x0

//The length of the data buffer in bytes
.global sm_data_len; sm_data_len:
.int 0x0

//The length of the data buffer in bytes
.global sm_data_start; sm_data_start:
