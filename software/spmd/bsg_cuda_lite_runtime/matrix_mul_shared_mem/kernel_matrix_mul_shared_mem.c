/*!
 * This kernel performs tiled matrix multiplication with use of tile-group-shared memory
 * For now the matrices are assumed to have the same X/Y dimension n.
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);





int  __attribute__ ((noinline)) kernel_matrix_mul_shared_mem(int *A, int *B, int *C, int n) {

	int thread_count_x = n / (__bsg_grid_dim_x * bsg_tiles_X);
	int thread_count_y = n / (__bsg_grid_dim_y * bsg_tiles_Y);

	int start_y = (__bsg_tile_group_id_y * bsg_tiles_Y + __bsg_y) * thread_count_y;
	int start_x = (__bsg_tile_group_id_x * bsg_tiles_X + __bsg_x) * thread_count_x;

	int sh_dim_x = thread_count_x * bsg_tiles_X;
	int sh_dim_y = thread_count_y * bsg_tiles_Y;	


	int *sh_A, *sh_B, *sh_C;
	bsg_tilegroup_int (sh_A, (sh_dim_y * sh_dim_x));
	bsg_tilegroup_int (sh_B, (sh_dim_y * sh_dim_x));
	bsg_tilegroup_int (sh_C, (sh_dim_y * sh_dim_x));



	for (int square_id = 0; square_id < n / sh_dim_x; square_id ++) { 


		// Each tile loads a (thread_count_x * thread_count_y) bloack of A & B from DRAM into shared memory 
		// Each iteration of the loop represetns a thread
		for (int iter_y = 0; iter_y < thread_count_y; iter_y ++) { 
			for (int iter_x = 0; iter_x < thread_count_x; iter_x ++) { 

				int A_id_y = start_y + iter_y;
				int A_id_x = sh_dim_x * square_id + __bsg_x * thread_count_x + iter_x;
				int B_id_y = sh_dim_y * square_id + __bsg_y * thread_count_y + iter_y;
				int B_id_x = start_x + iter_x; 
				
				int sh_id_y = __bsg_y * thread_count_y + iter_y;
				int sh_id_x = __bsg_x * thread_count_x + iter_x;
	

				bsg_tilegroup_store(sh_A, (sh_id_y * sh_dim_x + sh_id_x)  , A[A_id_y * n + A_id_x]);	
				bsg_tilegroup_store(sh_B, (sh_id_y * sh_dim_x + sh_id_x)  , B[B_id_y * n + B_id_x]);	
			}
		}
	
		bsg_tile_group_barrier(&r_barrier, &c_barrier); 
	
		for (int iter_y = 0; iter_y < thread_count_y; iter_y ++) { 
			for (int iter_x = 0; iter_x < thread_count_x; iter_x ++) { 

				int sum = 0; 
				for (int k = 0; k < sh_dim_x; k ++) { 
					int lc_A, lc_B;
					bsg_tilegroup_load(sh_A, (iter_y * sh_dim_x + k), lc_A);
					bsg_tilegroup_load(sh_B, (k * sh_dim_x + iter_x), lc_B);
					
					sum += lc_A * lc_B;
				}
				int lc_C;
				// at first iteration initalize lc_C to zero
				if (!square_id) { 
					bsg_tilegroup_store(sh_C, (iter_y * sh_dim_x + iter_x), sum);
				}
				else {
					
					int lc_C;
					bsg_tilegroup_load(sh_C, (iter_y * sh_dim_x + iter_x), lc_C);
					bsg_tilegroup_store(sh_C, (iter_y * sh_dim_x + iter_x) , (lc_C + sum));
				}
			}
		}

		bsg_tile_group_barrier(&r_barrier, &c_barrier); 			
	}

	// Each tile stores a (thread_count_x * thread_count_y) block of results back into DRAM 
	for (int iter_y = 0; iter_y < thread_count_y; iter_y ++) { 
		for (int iter_x = 0; iter_x < thread_count_x; iter_x ++) { 
			int C_id_y = start_y + iter_y;
			int C_id_x = start_x + iter_x;
			int sh_id_y = __bsg_y * thread_count_y + iter_y; 
			int sh_id_x = __bsg_x * thread_count_x + iter_x;
			
			bsg_tilegroup_load (sh_C, (sh_id_y * sh_dim_x + sh_id_x), C[C_id_y * n + C_id_x]);
		}
	}

	bsg_tile_group_barrier(&r_barrier, &c_barrier);
	

	return 0;
}
