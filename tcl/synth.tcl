yosys -import
# Load plugins
plugin -i slang

# Import commands from plugins to tcl interpreter
yosys -import

set top_module axis_sa

set new_params [list]
foreach param [lrange $argv 0 end] {
  lappend new_params -G $param
  puts "Setting $param"
}

eval read_slang axis_sa.sv --top $top_module $new_params

procs;;
clean -purge
setundef -zero

proc export_synth {output_path} {
  file mkdir $output_path
  write_json $output_path/synth.json
  # write_verilog $output_path/synth.v
}

flatten
puts [export_synth {output/0_proc}]

# Synthesize design
synth -top $top_module
clean -purge
autoname
setundef -zero

puts [export_synth {output/1_synth}]
