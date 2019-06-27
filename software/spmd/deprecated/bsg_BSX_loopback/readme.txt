This is a simple test case to test the loopback funciton.

Before testing, you should modified the testbench file so it will only load & reset  Tile(0,0)


========diff start =============
 
diff --git a/testbenches/common/v/bsg_manycore_spmd_loader.v b/testbenches/common/v/bsg_manycore_spmd_loader.v
index a05896e..22a5802 100644
--- a/testbenches/common/v/bsg_manycore_spmd_loader.v
+++ b/testbenches/common/v/bsg_manycore_spmd_loader.v
@@ -14,8 +14,8 @@ import bsg_noc_pkg   ::*; // {P=0, W, E, N, S}
    ,parameter tile_id_ptr_p   = -1
    ,parameter num_rows_p      = -1
    ,parameter num_cols_p      = -1
-   ,parameter load_rows_p     = num_rows_p
-   ,parameter load_cols_p     = num_cols_p
+   ,parameter load_rows_p     = 1
+   ,parameter load_cols_p     = 1
 
    ,parameter y_cord_width_lp  = `BSG_SAFE_CLOG2(num_rows_p + 1)
    ,parameter x_cord_width_lp  = `BSG_SAFE_CLOG2(num_cols_p)
diff --git a/testbenches/common/v/bsg_nonsynth_manycore_io_complex.v b/testbenches/common/v/bsg_nonsynth_manycore_io_complex.v
index c9b3023..5608c54 100644
--- a/testbenches/common/v/bsg_nonsynth_manycore_io_complex.v
+++ b/testbenches/common/v/bsg_nonsynth_manycore_io_complex.v
@@ -62,7 +62,7 @@ module bsg_nonsynth_manycore_io_complex
      end
 
    bsg_manycore_spmd_loader
-     #( .mem_size_p    (mem_size_p)
+     #( .mem_size_p    (24)
         ,.num_rows_p    (num_tiles_y_p)
         ,.num_cols_p    (num_tiles_x_p)
         ,.load_rows_p   ( load_rows_p)

========diff end =============
