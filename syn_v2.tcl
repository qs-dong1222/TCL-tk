############################
# Author : Qiu Shi
# For synthesizing the source vhdl
# version : 2.0
############################

source "./.synopsys_dc.setup"

############################
# build variables
############################
set pkgPathList [list "..."];
set entityName "...";
set architectureName "...";
set srcPath "...";
#set if the entity has generic parameter at ports
set generic_paramter_enable 0
#set the number corresponding to the generic parameters one by one in order, use "," as isolation like "1,2,3"
set generic_paramter_assignment_in_order "***"
#set flag if the eneity has subcomponents
set sub_comp_enable 1
set subCompPathList [list "..."]
#set if want to disable timing constraint presentation in timing report
set DisableClockConstraint 0

puts "please input the clock name of the top eneity: ";
set clockNameStr [gets stdin];
scan $clockNameStr "%s" clockName;
puts "clock name: $clockName";
puts "please input the desired clock period: ";
set clockPeriodStr [gets stdin];
scan $clockPeriodStr "%e" clockPeriod;
puts "clock period: $clockPeriod";

if { [regexp {(.+)\.(.+)} $clockPeriodStr matchContent intPart fracPart] } {
	set CLKvalStr "$intPart\_$fracPart";
} else {
	set CLKvalStr $clockPeriodStr;
}

##############################################################
# # # DON'T modify the following variables' definitions # # #
##############################################################
# vhdl netlist compiled
# puts "please input the file name of the vhdl netlist generated(without .vhdl extension): ";
# set fileNameStr [gets stdin];
# scan $fileNameStr "%s" vhdlFileName;
# puts "vhdl File Name: $vhdlFileName.vhdl";

set outputPath_vhdl "./syn_output/$entityName\_CLK$CLKvalStr.vhdl"
# verilog netlist compiled
# puts "please input the file name of the verilog netlist generated(without .v extension): ";
# set fileNameStr [gets stdin];
# scan $fileNameStr "%s" verilogFileName;
# puts "verilog File Name: $verilogFileName.v";
set outputPath_verilog "./syn_output/$entityName\_CLK$CLKvalStr.v"
# sdc file
# puts "please input the file name of the SDC file generated(without .sdc extension): ";
# set fileNameStr [gets stdin];
# scan $fileNameStr "%s" sdcFileName;
# puts "sdc File Name: $sdcFileName.sdc";
set outputPath_sdc "./syn_output/$entityName\_CLK$CLKvalStr.sdc"
# sdf file
# puts "please input the file name of the SDF file generated(without .sdf extension): ";
# set fileNameStr [gets stdin];
# scan $fileNameStr "%s" sdfFileName;
# puts "sdf File Name: $sdfFileName.sdf";
set outputPath_sdf "./syn_output/$entityName\_CLK$CLKvalStr.sdf"; #delay info file

puts "";

set timingReportName "./reports/Timing_$entityName\_CLK$CLKvalStr"
set areaReportName "./reports/Area_$entityName\_CLK$CLKvalStr"
set powerReportName "./reports/Power_$entityName\_CLK$CLKvalStr"
set resourcesReportName "./reports/Resources_$entityName\_CLK$CLKvalStr"

set tempDir "./temp"
file mkdir $tempDir
define_design_lib $entityName -path $tempDir

############################
# build report folder
############################
file mkdir "./work"
if {![file exists "./reports"]} {
	file mkdir "./reports";
}
if {![file exists "./syn_output"]} {
	file mkdir "./syn_output";
}



##################################
# enable ultra optimization
##################################
#set_ultra_optimization true;

############################
# analyze & elaborate
############################
foreach eachPkgPath $pkgPathList {
	analyze -library WORK -format vhdl $eachPkgPath
}

if {$sub_comp_enable != 1} {
	analyze -library WORK -format vhdl $srcPath
} else {
	foreach eachSubPath $subCompPathList {
		analyze -library WORK -format vhdl $eachSubPath
	}
	analyze -library WORK -format vhdl $srcPath
}

# ##########################################
set power_preserve_rtl_hier_names true
# ##########################################

if {$generic_paramter_enable != 1} {
	elaborate $entityName -architecture $architectureName -library WORK > ./elaborate.log
} else {
	elaborate $entityName -architecture $architectureName -parameters $generic_paramter_assignment_in_order -library WORK > ./elaborate.log
}


############################
# set clock
############################
create_clock -name $clockName -period $clockPeriod $clockName; #[get_ports $clockName]
#since the clock is a “special” signal in the design, we set the dont touch property
set_dont_touch_network $clockName
#Since the clock could be affected by jitter we can set the uncertainty of the clock signal
set_clock_uncertainty 0.07 [get_clocks $clockName]
#each input signal could arrive with a certain delay with respect to the clock.
#Assuming that all input signals have the same maximum input delay, we can set their input delay.
set_input_delay 0.5 -max -clock $clockName [remove_from_collection [all_inputs] $clockName]
#Similarly, we can set the maximum delay of output ports
set_output_delay 0.5 -max -clock $clockName [all_outputs]
#Finally, we can set the load of each output in our design. For the sake of simplicity we assume that the load of each output
#is the input capacitance of a buffer. Among the buffers available in this technology we choose the BUF X4,
#whose input port is named A
set OLOAD [load_of NangateOpenCellLibrary/BUF_X4/A]
set_load $OLOAD [all_outputs]
#where NangateOpenCellLibrary is the name of the target technology library.
#Set maximum delay of clock
#set_max_delay $clockPeriod -from [all_inputs] -to [all_outputs];

#############################################
# specify adder and mult implementations
#############################################
# adder
#set_implementation DW01_add/rpl [find cell *add_*];
#set_implementation DW01_add/cla [find cell *add_*];
#set_implementation DW01_add/pparch [find cell *add_*];
# mult
#set_implementation DW02_mult/csa [find cell *mult_*];
#set_implementation DW02_mult/pparch [find cell *mult_*];

############################
# compilation
############################
compile
#compile_ultra;
#compile -map_effort high

############################
# optimization
############################
#set_dont_touch *register_reg*;
#optimize_registers;

############################
# save the data required to complete the design and to perform switchingactivity-based power estimation.
############################
ungroup -all -flatten
change_names -hierarchy -rules verilog

############################
# save synthesized vhdl&verilog files
############################
write_sdf $outputPath_sdf
write -format vhdl -hierarchy -output $outputPath_vhdl
write -format verilog -hierarchy -output $outputPath_verilog
write_sdc -version 1.3 $outputPath_sdc

############################
# save reports
############################
if {$DisableClockConstraint} {
	read_vhdl $outputPath_vhdl;
}
report_resources > "$resourcesReportName.rpt"
report_timing > "$timingReportName.rpt"
report_area > "$areaReportName.rpt"
report_power > "$powerReportName.rpt"

##########################
# free space
##########################
exec rm -rf $tempDir;

if {[expr {[llength [glob -nocomplain "./dwsvf*"]] == 0}]} {
	puts "warning: no such files \"./dwsvf*\" to delete";
} else {
	foreach eachDelPath [glob "./dwsvf*"] {
		file delete -force $eachDelPath; #same command effect as above
	}
}

if {[expr {[llength [glob -nocomplain "./filenames*.log"]] == 0}]} {
	puts "warning: no such files \"./filenames*.log\" to delete";
} else {
	foreach eachDelPath [glob "./filenames*.log"] {
		file delete -force $eachDelPath; #same command effect as above
	}
}


#quit
