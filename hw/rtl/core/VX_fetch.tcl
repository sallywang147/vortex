

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

# Assert: After reset is deasserted, the fetch module should eventually make a fetch request
assert -name fetch_request_eventually -expr {
    $rose(!reset) |=> eventually (icache_bus_if.req_valid == 1);
}

# Cover: The fetch interface becomes valid at some point
cover -name fetch_if_valid -expr {
    eventually (fetch_if.valid == 1);
}

# Assert: When a schedule is valid and I-buffer is ready, a cache request is made
assert -name icache_request_fire -expr {
    always { (schedule_if.valid && ibuf_ready) -> (icache_req_valid == 1); }
}

# Assume: The instruction cache always accepts requests when valid
assume -name icache_req_ready -expr {
    always { icache_bus_if.req_valid == 1 -> icache_bus_if.req_ready == 1; }
}

# Assert: The fetch interface is ready when the cache response is valid
assert -name fetch_if_ready -expr {
    always { icache_bus_if.rsp_valid == 1 -> fetch_if.valid == 1; }
}

# Cover: A complete fetch cycle occurs
cover -name complete_fetch_cycle -expr {
    sequence complete_fetch;
        (!reset && schedule_if.valid && schedule_if.ready) ##1
        icache_bus_if.req_valid && icache_bus_if.req_ready ##1
        icache_bus_if.rsp_valid && icache_bus_if.rsp_ready ##1
        fetch_if.valid && fetch_if.ready;
    endsequence
    complete_fetch;
}

set_engine_mode {K C Tri I N AD AM Hp B}
set_proofgrid_per_engine_max_jobs 32
set_proofgrid_max_jobs 32
set_prove_time_limit 12m
set_prove_per_property_time_limit 12m

prove -all

puts "END"
# Generate a comprehensive report
report -csv -results -file "verification_report.csv" -force

# Exit the tool
exit
