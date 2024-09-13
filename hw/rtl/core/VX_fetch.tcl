

# Read in the necessary HDL files
# Ensure that 'VX_define.vh' is accessible in the include path
analyze +incdir+../ -sv VX_fetch.sv

# Define any macros that might not be defined in the included files
set_define STRING string
set_define SCOPE_IO_DECL
set_define UNUSED_SPARAM(x)
set_define UNUSED_VAR(x)
set_define UNUSED_PIN(x)
set_define RUNTIME_ASSERT(condition, message)
set_define DBG_SCOPE_FETCH
set_define DBG_TRACE_MEM
set_define IGNORE_UNUSED_BEGIN
set_define IGNORE_UNUSED_END

# Define parameter values if they are not set in 'VX_define.vh'
set_define UUID_WIDTH 32
set_define NW_WIDTH 5
set_define PC_BITS 32
set_define NUM_THREADS 32
set_define NUM_WARPS 16
set_define IBUF_SIZE 8
set_define ICACHE_ADDR_WIDTH 12
set_define ICACHE_TAG_WIDTH 16
set_define ICACHE_WORD_SIZE 4

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
