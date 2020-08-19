// Structure for vanilla core profiler bsg_cuda_print_stat tag formatting
// <stat type>   -   <y cord>   -   <x cord>   -   <tile group id>   -   <tag>
//   2 bits      -    6 bits    -    6 bits    -      14 bits        -  4 bits

package bsg_manycore_profile_pkg;

    // Type of a stat message can be start, end or just stat
    typedef enum logic [1:0] {
        e_tag_stat
        ,e_tag_start
        ,e_tag_end
    } bsg_manycore_stat_type_e;

    // The stat tag message incorporates the following:
    // the type of the stat (start, end, stat)
    // x,y coordinates of the tile that triggerd the print_stat message
    // the tile group id of the tile 
    // the tag message passed into the instruction by programmer
    typedef struct packed {
        bsg_manycore_stat_type_e stat_type;
        logic [5:0] y_cord;
        logic [5:0] x_cord;
        logic [13:0] tile_group_id;
        logic [3:0] tag;
    } bsg_manycore_vanilla_core_stat_tag_s;

endpackage    
