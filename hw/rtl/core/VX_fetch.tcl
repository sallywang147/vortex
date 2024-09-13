

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

# Assertion to check that icache_req_valid is asserted when schedule_if.valid and ibuf_ready are both high.
assert asgpt__icache_req_valid_is_high:
  (VX_fetch.schedule_if.valid && VX_fetch.ibuf_ready) |-> VX_fetch.icache_req_valid;

# Assertion to ensure that when icache_req_valid and icache_req_ready are both asserted, icache_req_fire is also asserted.
assert asgpt__icache_req_fire_asserted:
  (VX_fetch.icache_req_valid && VX_fetch.icache_req_ready) |-> VX_fetch.icache_req_fire;

# Assertion to check that when schedule_if.valid is asserted, schedule_if.ready will be asserted only if icache_req_ready and ibuf_ready are both high.
assert asgpt__schedule_if_ready_condition:
  VX_fetch.schedule_if.valid |-> (VX_fetch.schedule_if.ready == (VX_fetch.icache_req_ready && VX_fetch.ibuf_ready));

# Assertion to check that data in the tag_store is written correctly when icache_req_fire is asserted.
assert asgpt__tag_store_write_correct:
  VX_fetch.icache_req_fire |-> (VX_fetch.tag_store.waddr == VX_fetch.req_tag && VX_fetch.tag_store.wdata == {VX_fetch.schedule_if.data.PC, VX_fetch.schedule_if.data.tmask});

# Assertion to ensure that fetch_if.valid is only asserted when icache_bus_if.rsp_valid is asserted.
assert asgpt__fetch_if_valid_asserted:
  VX_fetch.icache_bus_if.rsp_valid |-> VX_fetch.fetch_if.valid;

# Assertion to verify that if fetch_if.valid is asserted, fetch_if.ready is asserted for icache_bus_if.rsp_ready.
assert asgpt__icache_bus_if_rsp_ready_condition:
  VX_fetch.fetch_if.valid |-> (VX_fetch.icache_bus_if.rsp_ready == VX_fetch.fetch_if.ready);

# Cover property to check that icache_req_fire is covered at least once.
cover asgpt__icache_req_fire_covered:
  VX_fetch.icache_req_fire;

# Cover property to check that fetch_if.valid is covered at least once.
cover asgpt__fetch_if_valid_covered:
  VX_fetch.fetch_if.valid;

# Assume property to ensure icache_req_ready behaves correctly.
assume asgpt__icache_req_ready_assume:
  (VX_fetch.icache_req_valid && VX_fetch.icache_req_ready) |-> (VX_fetch.icache_req_fire);

# Assume property that ensures the pending_ibuf_full signal behaves correctly.
assume asgpt__pending_ibuf_full_assume:
  (VX_fetch.icache_req_fire && (VX_fetch.schedule_if.data.wid == i)) |-> (VX_fetch.pending_ibuf_full[i] == (VX_fetch.icache_req_fire && (VX_fetch.schedule_if.data.wid == i)));


puts "END"
# Generate a comprehensive report
report -csv -results -file "verification_report.csv" -force

# Exit the tool
exit
