yosys -import
# Load plugins
plugin -i slang

# Import commands from plugins to tcl interpreter
yosys -import

set tcl_dir [file dirname [file normalize [info script]]]

array set opt {
  top_module      axis_sa
  rtl_path        ""
  output_dir      synth_output
  params          {}
}
set opt(rtl_path) "$tcl_dir/../rtl/axis_sa.sv"

# Helper to export netlist
proc export_synth {output_dir} {
  file mkdir $output_dir
  write_json $output_dir/synth.json
}


# Parse arguments
foreach arg $::argv {
  # Match pattern: key=value
  if {[regexp {(\w+)=([^ ]+)} $arg -> key val]} {
    if {$key eq "output_dir"} {
      set $opt($key) $val
    } else {
      lappend opt(params) -G$key=$val
    }
  }
}

# Read RTL
eval read_slang $opt(rtl_path) --top $opt(top_module) $opt(params)

procs;;
clean -purge
setundef -zero
flatten

# Export process netlist
export_synth "$opt(output_dir)/0_proc"

# Synthesize design
synth
clean -purge
autoname
setundef -zero
export_synth "$opt(output_dir)/1_synth"