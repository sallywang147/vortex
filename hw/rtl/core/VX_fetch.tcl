

# Read in the necessary HDL files
# Ensure that 'VX_define.vh' is accessible in the include path
analyze +incdir+../ -sv VX_gpu_pkg.sv VX_fetch.sv


# Set the top-level module for verification
elaborate -bbox_m VX_dp_ram -bbox_m VX_elastic_buffer -top VX_fetch

clock clk
reset reset


# Enable assertion checking
set -assert true

# Set formal verification options
set -formal_depth 20
set -model_assumptions true

set_engine_mode {K C Tri I N AD AM Hp B}
set_proofgrid_per_engine_max_jobs 32
set_proofgrid_max_jobs 32
set_prove_time_limit 12m
set_prove_per_property_time_limit 12m

# Run the formal verification
task -set mytask

puts "END"
# Generate a comprehensive report
report -task mytask -csv -results -file "verification_report.csv" -force

# Exit the tool
exit
