source {/home/vagrant/git/livt/livt-flan-t5-arty-a7-100t/scripts/limit_vivado_threads.tcl}
source {/home/vagrant/git/livt/livt-flan-t5-arty-a7-100t/scripts/preprocess_vivado_vhdl.tcl}
preprocessLivtLangPackageFile {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/generated/Livt.Lang.Package.vhd}
create_project -in_memory -part xc7a100tcsg324-1
read_vhdl -vhdl2008 [list {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/generated/Livt.Lang.IComponent.Package.vhd} {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/generated/Livt.Lang.IContext.Package.vhd} {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/generated/Livt.Lang.Package.vhd} {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/generated/Livt.ML.Numeric.ScheduledRequantizeUInt8.Package.vhd} {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/generated/Livt.ML.Numeric.ScheduledRequantizeUInt8.vhd} {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/generated/Livt.Math.Arithmetic.IIntegerDivision_g_integer_sig_aa273db78b38.Package.vhd} {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/generated/Livt.Math.Arithmetic.IIntegerDivision_g_unsignedinteger_sig_809b61f6ff02.Package.vhd} {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/generated/Livt.Math.Arithmetic.IntegerDivision_g_32_sig_4fa0a627f162.Package.vhd} {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/generated/Livt.Math.Arithmetic.IntegerDivision_g_32_sig_4fa0a627f162.vhd} {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/generated/Livt.Math.Arithmetic.UnsignedDivision_g_32_sig_db0f7854530e.Package.vhd} {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/generated/Livt.Math.Arithmetic.UnsignedDivision_g_32_sig_db0f7854530e.vhd} {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/wrapper.vhd}]
read_xdc {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/clock.xdc}
synth_design -top livt_ml_numeric_scheduledrequantizeuint8_slice -part xc7a100tcsg324-1 -mode out_of_context -directive AreaOptimized_high -control_set_opt_threshold 16
report_utilization -hierarchical -file {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/utilization.rpt}
report_timing_summary -report_unconstrained -check_timing_verbose -file {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/timing.rpt}
set latches [get_cells -hier -quiet -filter {REF_NAME =~ LD*}]
puts "FT5_SLICE_LATCHES=[llength $latches]"
write_checkpoint -force {/tmp/livt-arithmetic-audit/requantize-synthesis-complete/synth.dcp}
if {[llength $latches]} {error "Unexpected latches"}
puts "FT5_SLICE_PASS"
exit
