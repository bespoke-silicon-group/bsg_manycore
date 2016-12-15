#ifndef __CHAINED_CONFIG__
#define __CHAINED_CONFIG__
/******************************************************************************/
//additional cycles between each round
#define DELAY_CYCLE 0
//how many rounds we want to run ?
#define MAX_ROUND_NUM 16 
//the vector length 
#define BUF_LEN   128

/******************************************************************************/
//the configutations of the proc array. see chained_core.h and proc.c for different
//configs.
//#define CONFIG eALL_PASS_FUNCS
#define CONFIG eONE_COPY_FUNCS
/******************************************************************************/

#endif
