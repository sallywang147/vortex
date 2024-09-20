# ----------------------------------------
# Jasper Version Info
# tool      : Jasper 2023.12
# platform  : Linux 3.10.0-1160.119.1.el7.x86_64
# version   : 2023.12p001 64 bits
# build date: 2024.01.23 16:09:24 UTC
# ----------------------------------------
# started   : 2024-09-20 03:00:49 PDT
# hostname  : cadence7.(none)
# pid       : 16743
# arguments : '-label' 'session_0' '-console' '//127.0.0.1:40307' '-nowindow' '-style' 'windows' '-data' 'AAAA9nicVY47DwFBFIW/8UhQiFKtJxshUWyh0RGhEJ1s1jsTRKxCw0/1T8YxG4m5xT2P3JN7DBA/nXP4KT60GoyZMGekPWUhhCZ9ugyIGJKSsMZyEIvynHnnSGwI56sLoTN7BQjlX5g/o06bE2dW7Mj0C1rqspTesuGm33vPMzWxdLxjdVVRLlXuLl4Tv3CVOkqV1LsnrPIBLpYa+Q==' '-proj' '/home/sallyjw/micro24-ae-synthlc/vortex/hw/rtl/core/a4/sessionLogs/session_0' '-init' '-hidden' '/home/sallyjw/micro24-ae-synthlc/vortex/hw/rtl/core/a4/.tmp/.initCmds.tcl' 'VX_fetch_full.tcl'
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
assert -name fetch_request_eventually {
    $rose(!reset) |-> icache_bus_if.req_valid == 1
}

# Cover: The fetch interface becomes valid at some point
cover -name fetch_if_valid {
     fetch_if.valid == 1
}

# Assert: When a schedule is valid and I-buffer is ready, a cache request is made
assert -name icache_request_fire {
    always { schedule_if.valid && ibuf_ready -> icache_req_valid == 1 }
}

# Remove the assumption that icache_bus_if.req_ready is always ready
# to allow exploration of cases where it might not be ready
#assume -name icache_req_ready  {
#    always { icache_bus_if.req_valid == 1 -> icache_bus_if.req_ready == 1 }
#}

# Assert: The fetch interface is valid when the cache response is valid
assert -name fetch_if_valid_when_rsp_valid {
    always { icache_bus_if.rsp_valid == 1 -> fetch_if.valid == 1 }
}

# Cover: A complete fetch cycle occurs
cover -name complete_fetch_cycle {
        !reset && schedule_if.valid && schedule_if.ready ##1
        icache_bus_if.req_valid && icache_bus_if.req_ready ##1
        icache_bus_if.rsp_valid && icache_bus_if.rsp_ready ##1
        fetch_if.valid && fetch_if.ready
}

# Cover: The cache request fires
cover -name icache_req_fire {
    icache_req_fire == 1
}

# Assert: When schedule is valid, PC should not be zero
assert -name schedule_if_PC_nonzero {
    always { schedule_if.valid == 1 -> schedule_if.data.PC != 0 }
}

# Cover: Attempt to cover the case where PC is zero (should trigger assertion)
cover -name schedule_if_PC_zero {
    schedule_if.valid == 1 && schedule_if.data.PC == 0
}

# Assume: Schedule interface becomes valid eventually
assume -name schedule_if_valid_eventually {
    $rose(!reset) |-> schedule_if.valid == 1
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
