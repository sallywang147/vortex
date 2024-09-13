

# Read in the necessary HDL files
# Ensure that 'VX_define.vh' is accessible in the include path
analyze +incdir+../ -sv VX_gpu_pkg.sv VX_fetch.sv


# Set the top-level module for verification
set -top VX_fetch

clock clk
reset rst
# Define the clock signal
clk -period 10

# Define reset behavior: assert reset for the first two cycles
clk reset -active high -cycles 2

# Enable assertion checking
set -assert true

# Set formal verification options
set -formal_depth 20
set -model_assumptions true

# Run the formal verification
run_verify

# Generate a comprehensive report
report -task mytask -csv -results -file "verification_report.csv" -force

# Exit the tool
exit
