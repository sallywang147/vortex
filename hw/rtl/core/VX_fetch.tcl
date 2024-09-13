# Set the design libraries and include directories
set_option -vlog_std sv2012
set_option -default_includes .
set_option -default_lib WORK

# Read in the necessary HDL files
read_hdl -sv +incdir+./ VX_define.vh VX_gpu_pkg.sv VX_fetch.sv

# Set the top-level module for verification
set_top VX_fetch

# Define the clock signal
define_clock clk -period 10

# Define reset behavior: assert reset for the first two cycles
add_reset clk reset -active high -cycles 2

# Enable assertion checking
set_option -assert true

# Set formal verification options
set_option -formal_depth 20
set_option -model_assumptions true

# Run the formal verification
run_verify

# Generate a comprehensive report
report_results -all -output verification_report.txt

# Exit the tool
exit
