/* enum cuda_graph_argv_idx { */
/*         COLUMNS_VECTOR = 0,         */
/*         COLUMNS_VECTOR_SZ, */
/*         ROW_PTRS_VECTOR, */
/*         ROW_PTRS_VECTOR_SZ, */
/*         RESULTS_VECTOR, */
/*         RESULTS_VECTOR_SZ, */
/* } ; */
#include <stdint.h>

static uint32_t degree(uint32_t v,
                       uint32_t *columns,  uint32_t columns_sz,
                       uint32_t *row_ptrs, uint32_t row_ptrs_sz)
{
        if ((v+1) < row_ptrs_sz) {
                return row_ptrs[v+1]-row_ptrs[v];
        } else {
                return columns_sz-row_ptrs[v];
        }
}

void graph_degree_count(uint32_t *columns,  uint32_t columns_sz,
                        uint32_t *row_ptrs, uint32_t row_ptrs_sz,
                        uint32_t *results,  uint32_t results_sz)
{
        uint32_t i;

        for (i = 0; i < results_sz; i++)
                results[i] = degree(i, columns, columns_sz, row_ptrs, row_ptrs_sz);

        return;
}
