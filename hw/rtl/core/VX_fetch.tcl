

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

# Assume: The instruction cache always accepts requests when valid
assume -name icache_req_ready  {
    always { icache_bus_if.req_valid == 1 -> icache_bus_if.req_ready == 1 }
}

# Assert: The fetch interface is ready when the cache response is valid
assert -name fetch_if_ready {
    always { icache_bus_if.rsp_valid == 1 -> fetch_if.valid == 1 }
}

# Cover: A complete fetch cycle occurs
#cover -name complete_fetch_cycle {
#    sequence complete_fetch
#        !reset && schedule_if.valid && schedule_if.ready ##1
#        icache_bus_if.req_valid && icache_bus_if.req_ready ##1
#        icache_bus_if.rsp_valid && icache_bus_if.rsp_ready ##1
#        fetch_if.valid && fetch_if.ready
#    endsequence
#   complete_fetch
#}

// Checking if req_tag is correctly derived from schedule_if.data.wid
// Ensures that req_tag is always equal to schedule_if.data.wid
asgpt__req_tag_correct: assert property (req_tag == VX_fetch.schedule_if.data.wid);

// Checking if {rsp_uuid, rsp_tag} is correctly derived from icache_bus_if.rsp_data.tag
// Ensures that rsp_uuid and rsp_tag are correctly extracted from the icache response tag
asgpt__rsp_tag_uuid_correct: assert property ({rsp_uuid, rsp_tag} == VX_fetch.icache_bus_if.rsp_data.tag);

// Checking if icache_req_fire is asserted when both icache_req_valid and icache_req_ready are true
// This ensures that the icache request is fired correctly
asgpt__icache_req_fire_correct: assert property (icache_req_fire == (VX_fetch.icache_req_valid && VX_fetch.icache_req_ready));

// Checking if schedule_if.ready is correctly assigned
// Ensures that schedule_if.ready is asserted only when icache_req_ready and ibuf_ready are both true
asgpt__schedule_if_ready_correct: assert property (VX_fetch.schedule_if.ready == (VX_fetch.icache_req_ready && VX_fetch.ibuf_ready));

// Checking if ibuf_ready is correctly derived based on pending_ibuf_full
// This ensures that ibuf_ready is the complement of pending_ibuf_full for the current warp
asgpt__ibuf_ready_correct: assert property (VX_fetch.ibuf_ready == ~VX_fetch.pending_ibuf_full[VX_fetch.schedule_if.data.wid]);

// Checking if icache_req_valid is correctly asserted
// Ensures that icache_req_valid is true when schedule_if.valid and ibuf_ready are both true
asgpt__icache_req_valid_correct: assert property (VX_fetch.icache_req_valid == (VX_fetch.schedule_if.valid && VX_fetch.ibuf_ready));

// Checking if icache_req_addr is correctly derived from schedule_if.data.PC
// Ensures that icache_req_addr is correctly sliced from schedule_if.data.PC
asgpt__icache_req_addr_correct: assert property (VX_fetch.icache_req_addr == VX_fetch.schedule_if.data.PC[1 +: `ICACHE_ADDR_WIDTH]);

// Checking if icache_req_tag is correctly formed
// Ensures that icache_req_tag is the concatenation of schedule_if.data.uuid and req_tag
asgpt__icache_req_tag_correct: assert property (VX_fetch.icache_req_tag == {VX_fetch.schedule_if.data.uuid, VX_fetch.req_tag});

// Checking if fetch_if.valid is correctly assigned
// Ensures that fetch_if.valid is asserted when icache_bus_if.rsp_valid is true
asgpt__fetch_if_valid_correct: assert property (VX_fetch.fetch_if.valid == VX_fetch.icache_bus_if.rsp_valid);

// Checking if fetch_if.data is correctly assigned
// Ensures that fetch_if.data is correctly assigned from the icache response data and relevant signals
asgpt__fetch_if_data_correct: assert property (
    (VX_fetch.fetch_if.data.tmask == VX_fetch.rsp_tmask) &&
    (VX_fetch.fetch_if.data.wid == VX_fetch.rsp_tag) &&
    (VX_fetch.fetch_if.data.PC == VX_fetch.rsp_PC) &&
    (VX_fetch.fetch_if.data.instr == VX_fetch.icache_bus_if.rsp_data.data) &&
    (VX_fetch.fetch_if.data.uuid == VX_fetch.rsp_uuid)
);

// Checking if icache_bus_if.req_data fields are correctly assigned
// Ensures that the fields of icache_bus_if.req_data are correctly set
asgpt__icache_req_data_correct: assert property (
    (VX_fetch.icache_bus_if.req_data.atype == '0) &&
    (VX_fetch.icache_bus_if.req_data.rw == 1'b0) &&
    (VX_fetch.icache_bus_if.req_data.byteen == 4'b1111) &&
    (VX_fetch.icache_bus_if.req_data.data == '0)
);

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
