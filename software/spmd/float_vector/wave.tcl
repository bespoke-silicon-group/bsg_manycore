# Begin_DVE_Session_Save_Info
# DVE view(Wave.1 ) session
# Saved on Thu Jun 20 10:30:06 2019
# Toplevel windows open: 2
# 	TopLevel.1
# 	TopLevel.2
#   Wave.1: 14 signals
# End_DVE_Session_Save_Info

# DVE version: L-2016.06-SP2-15_Full64
# DVE build date: Mar 11 2018 22:07:39


#<Session mode="View" path="/mnt/bsg/diskbits/dcjung/bsg/bsg_manycore/software/spmd/float_vector/session.vcdplus.vpd.tcl" type="Debug">

#<Database>

gui_set_time_units 1ps
#</Database>

# DVE View/pane content session: 

# Begin_DVE_Session_Save_Info (Wave.1)
# DVE wave signals session
# Saved on Thu Jun 20 10:30:06 2019
# 14 signals
# End_DVE_Session_Save_Info

# DVE version: L-2016.06-SP2-15_Full64
# DVE build date: Mar 11 2018 22:07:39


#Add ncecessay scopes

gui_set_time_units 1ps

set _wave_session_group_1 Group1
if {[gui_sg_is_group -name "$_wave_session_group_1"]} {
    set _wave_session_group_1 [gui_sg_generate_new_name]
}
set Group1 "$_wave_session_group_1"

gui_sg_addsignal -group "$_wave_session_group_1" { {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.clk_i} {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.reset_i} {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.stall_fp} {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.fp_exe_valid} {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.fp_exe_debug} {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.fpu1_r} {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.fpu2_r} {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.fpu3_r} {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.fp_wb_debug} }

set _wave_session_group_2 Group2
if {[gui_sg_is_group -name "$_wave_session_group_2"]} {
    set _wave_session_group_2 [gui_sg_generate_new_name]
}
set Group2 "$_wave_session_group_2"

gui_sg_addsignal -group "$_wave_session_group_2" { {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.float_rf_waddr} {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.float_rf_wdata} {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.float_rf_wen} }

set _wave_session_group_3 Group3
if {[gui_sg_is_group -name "$_wave_session_group_3"]} {
    set _wave_session_group_3 [gui_sg_generate_new_name]
}
set Group3 "$_wave_session_group_3"

gui_sg_addsignal -group "$_wave_session_group_3" { {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.fp_wb_r} }

set _wave_session_group_4 Group4
if {[gui_sg_is_group -name "$_wave_session_group_4"]} {
    set _wave_session_group_4 [gui_sg_generate_new_name]
}
set Group4 "$_wave_session_group_4"

gui_sg_addsignal -group "$_wave_session_group_4" { {V1:test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.float_remote_load_resp_v_i} }
if {![info exists useOldWindow]} { 
	set useOldWindow true
}
if {$useOldWindow && [string first "Wave" [gui_get_current_window -view]]==0} { 
	set Wave.1 [gui_get_current_window -view] 
} else {
	set Wave.1 [lindex [gui_get_window_ids -type Wave] 0]
if {[string first "Wave" ${Wave.1}]!=0} {
gui_open_window Wave
set Wave.1 [ gui_get_current_window -view ]
}
}

set groupExD [gui_get_pref_value -category Wave -key exclusiveSG]
gui_set_pref_value -category Wave -key exclusiveSG -value {false}
set origWaveHeight [gui_get_pref_value -category Wave -key waveRowHeight]
gui_list_set_height -id Wave -height 25
set origGroupCreationState [gui_list_create_group_when_add -wave]
gui_list_create_group_when_add -wave -disable
gui_marker_set_ref -id ${Wave.1}  C1
gui_wv_zoom_timerange -id ${Wave.1} 6514875 6515467
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group1}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group2}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group3}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group4}]
gui_list_expand -id ${Wave.1} {test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.fp_exe_debug}
gui_list_expand -id ${Wave.1} {test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.fpu1_r}
gui_list_expand -id ${Wave.1} {test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.fpu2_r}
gui_list_expand -id ${Wave.1} {test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.fpu3_r}
gui_list_expand -id ${Wave.1} {test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.fp_wb_debug}
gui_list_expand -id ${Wave.1} {test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.fp_wb_r}
gui_list_select -id ${Wave.1} {{test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.float_rf_waddr} {test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.float_rf_wdata} {test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.vtrace.float_rf_wen} }
gui_seek_criteria -id ${Wave.1} {Any Edge}


gui_set_pref_value -category Wave -key exclusiveSG -value $groupExD
gui_list_set_height -id Wave -height $origWaveHeight
if {$origGroupCreationState} {
	gui_list_create_group_when_add -wave -enable
}
if { $groupExD } {
 gui_msg_report -code DVWW028
}
gui_list_set_filter -id ${Wave.1} -list { {Buffer 1} {Input 1} {Others 1} {Linkage 1} {Output 1} {Parameter 1} {All 1} {Aggregate 1} {LibBaseMember 1} {Event 1} {Assertion 1} {Constant 1} {Interface 1} {BaseMembers 1} {Signal 1} {$unit 1} {Inout 1} {Variable 1} }
gui_list_set_filter -id ${Wave.1} -text {*}
gui_list_set_insertion_bar  -id ${Wave.1} -group ${Group4}  -item {test_bsg_manycore.UUT.y[1].x[0].tile.proc.h.z.vcore.float_remote_load_resp_v_i} -position below

gui_marker_move -id ${Wave.1} {C1} 6515172
gui_view_scroll -id ${Wave.1} -vertical -set 0
gui_show_grid -id ${Wave.1} -enable false
#</Session>

