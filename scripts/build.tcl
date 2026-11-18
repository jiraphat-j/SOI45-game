# build.tcl — create the Vivado project and (optionally) build the bitstream.
#
#   Create project only (then open build/soi45.xpr in the GUI):
#     vivado -mode batch -source scripts/build.tcl
#   Create + synth + impl + bitstream:
#     vivado -mode batch -source scripts/build.tcl -tclargs bit
#   Nexys A7-50T instead of 100T:
#     vivado -mode batch -source scripts/build.tcl -tclargs bit xc7a50ticsg324-1L
#
# Run from the repository root.

set root [file normalize [file dirname [info script]]/..]
set mode [expr {[llength $argv] > 0 ? [lindex $argv 0] : "project"}]
set part [expr {[llength $argv] > 1 ? [lindex $argv 1] : "xc7a100tcsg324-1"}]

create_project soi45 $root/build -part $part -force
set_property target_language Verilog [current_project]

add_files [glob $root/rtl/*.v $root/rtl/*/*.v]
add_files -norecurse [glob $root/assets/sprite_mem/*.mem]
add_files -fileset constrs_1 [list $root/constraints/nexys_a7.xdc]
add_files -fileset sim_1 [glob $root/sim/*.v]
set_property top top [current_fileset]
set_property top tb_demo [get_filesets sim_1]
update_compile_order -fileset sources_1

if {$mode eq "bit"} {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    open_run impl_1
    report_utilization -file $root/build/utilization.txt
    report_timing_summary -file $root/build/timing.txt
    puts "BITSTREAM: $root/build/soi45.runs/impl_1/top.bit"
}
