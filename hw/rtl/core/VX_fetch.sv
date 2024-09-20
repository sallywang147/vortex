// Copyright © 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`include "VX_define.vh"
`include "mem/VX_mem_bus_if.sv"
`include "interfaces/VX_schedule_if.sv"
`include "interfaces/VX_fetch_if.sv"

module VX_fetch import VX_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID = ""
) (
    `SCOPE_IO_DECL

    input  wire             clk,
    input  wire             reset,

    // Icache interface
   // VX_mem_bus_if.master = 0
    VX_mem_bus_if.master    icache_bus_if,

    // inputs
   // VX_schedule_if.slave = 0 
    VX_schedule_if.slave    schedule_if,

    // outputs
   // VX_fetch_if.master = 0
    VX_fetch_if.master      fetch_if
);

    wire icache_req_valid;
    wire [ICACHE_ADDR_WIDTH-1:0] icache_req_addr;
    wire [ICACHE_TAG_WIDTH-1:0] icache_req_tag;
    wire icache_req_ready;

    wire [`UUID_WIDTH-1:0] rsp_uuid;
    wire [`NW_WIDTH-1:0] req_tag, rsp_tag;

    wire icache_req_fire = icache_req_valid && icache_req_ready;

    assign req_tag = schedule_if.data.wid;

    assign {rsp_uuid, rsp_tag} = icache_bus_if.rsp_data.tag;

    wire [`PC_BITS-1:0] rsp_PC;    //instruction identifying register (IIR)
    wire [`NUM_THREADS-1:0] rsp_tmask;

    VX_dp_ram #(
        .DATAW  (`PC_BITS + `NUM_THREADS),
        .SIZE   (`NUM_WARPS),
        .LUTRAM (1)
    ) tag_store (
        .clk   (clk),
        .read  (1'b1),
        .write (icache_req_fire),
        .waddr (req_tag),
        .wdata ({schedule_if.data.PC, schedule_if.data.tmask}),
        .raddr (rsp_tag),
        .rdata ({rsp_PC, rsp_tmask})
    );

`ifndef L1_ENABLE
    // Ensure that the ibuffer doesn't fill up.
    // This resolves potential deadlock if ibuffer fills and the LSU stalls the execute stage due to pending dcache requests.
    // This issue is particularly prevalent when the icache and dcache are disabled and both requests share the same bus.
    wire [`NUM_WARPS-1:0] pending_ibuf_full;
    for (genvar i = 0; i < `NUM_WARPS; ++i) begin
        VX_pending_size #(
            .SIZE (`IBUF_SIZE)
        ) pending_reads (
            .clk   (clk),
            .reset (reset),
            .incr  (icache_req_fire && schedule_if.data.wid == i),
            .decr  (fetch_if.ibuf_pop[i]),
            `UNUSED_PIN (empty),
            `UNUSED_PIN (alm_empty),
            .full  (pending_ibuf_full[i]),
            `UNUSED_PIN (alm_full),
            `UNUSED_PIN (size)
        );
    end
    wire ibuf_ready = ~pending_ibuf_full[schedule_if.data.wid];
`else
    wire ibuf_ready = 1'b1;
`endif

    `RUNTIME_ASSERT((!schedule_if.valid || schedule_if.data.PC != 0),
        ("%t: *** %s invalid PC=0x%0h, wid=%0d, tmask=%b (#%0d)", $time, INSTANCE_ID, {schedule_if.data.PC, 1'b0}, schedule_if.data.wid, schedule_if.data.tmask, schedule_if.data.uuid))

    // Icache Request
    // (ufsm, IIR)

    assign icache_req_valid = schedule_if.valid && ibuf_ready;
    assign icache_req_addr  = schedule_if.data.PC[1 +: ICACHE_ADDR_WIDTH]; 
    assign icache_req_tag   = {schedule_if.data.uuid, req_tag};
    assign schedule_if.ready = icache_req_ready && ibuf_ready;

    VX_elastic_buffer #(
        .DATAW   (ICACHE_ADDR_WIDTH + ICACHE_TAG_WIDTH),
        .SIZE    (2),
        .OUT_REG (1) // external bus should be registered
    ) req_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (icache_req_valid),
        .ready_in  (icache_req_ready),
        .data_in   ({icache_req_addr, icache_req_tag}),
        .data_out  ({icache_bus_if.req_data.addr, icache_bus_if.req_data.tag}),
        .valid_out (icache_bus_if.req_valid),
        .ready_out (icache_bus_if.req_ready)
    );

    assign icache_bus_if.req_data.atype  = '0;
    assign icache_bus_if.req_data.rw     = 0;
    assign icache_bus_if.req_data.byteen = 4'b1111;
    assign icache_bus_if.req_data.data   = '0;

    // Icache Response
    // (ufsm, IIR)

    assign fetch_if.valid = icache_bus_if.rsp_valid;
    assign fetch_if.data.tmask = rsp_tmask;
    assign fetch_if.data.wid   = rsp_tag;
    assign fetch_if.data.PC    = rsp_PC; 
    assign fetch_if.data.instr = icache_bus_if.rsp_data.data;
    assign fetch_if.data.uuid  = rsp_uuid;
    assign icache_bus_if.rsp_ready = fetch_if.ready;

`ifdef DBG_SCOPE_FETCH
    wire schedule_fire = schedule_if.valid && schedule_if.ready;
    wire icache_rsp_fire = icache_bus_if.rsp_valid && icache_bus_if.rsp_ready;
    VX_scope_tap #(
        .SCOPE_ID (1),
        .TRIGGERW (4),
        .PROBEW (`UUID_WIDTH + `NW_WIDTH + `NUM_THREADS + `PC_BITS +
            ICACHE_TAG_WIDTH + ICACHE_WORD_SIZE + ICACHE_ADDR_WIDTH +
            (ICACHE_WORD_SIZE*8) + ICACHE_TAG_WIDTH)
    ) scope_tap (
        .clk (clk),
        .reset (scope_reset),
        .start (1'b0),
        .stop (1'b0),
        .triggers ({
            reset,
            schedule_fire,
            icache_req_fire,
            icache_rsp_fire
        }),
        .probes ({ // (ufsm, IIR)
            schedule_if.data.uuid, schedule_if.data.wid, schedule_if.data.tmask, schedule_if.data.PC,
            icache_bus_if.req_data.tag, icache_bus_if.req_data.byteen, icache_bus_if.req_data.addr,
            icache_bus_if.rsp_data.data, icache_bus_if.rsp_data.tag
        }),
        .bus_in (scope_bus_in),
        .bus_out (scope_bus_out)
    );
`else
    `SCOPE_IO_UNUSED(1)
`endif

`ifdef DBG_TRACE_MEM
    wire schedule_fire = schedule_if.valid && schedule_if.ready;
    wire fetch_fire = fetch_if.valid && fetch_if.ready;
    always @(posedge clk) begin
        if (schedule_fire) begin
            `TRACE(1, ("%d: %s req: wid=%0d, PC=0x%0h, tmask=%b (#%0d)\n", $time, INSTANCE_ID, schedule_if.data.wid, {schedule_if.data.PC, 1'b0}, schedule_if.data.tmask, schedule_if.data.uuid));
        end
        if (fetch_fire) begin
            `TRACE(1, ("%d: %s rsp: wid=%0d, PC=0x%0h, tmask=%b, instr=0x%0h (#%0d)\n", $time, INSTANCE_ID, fetch_if.data.wid, {fetch_if.data.PC, 1'b0}, fetch_if.data.tmask, fetch_if.data.instr, fetch_if.data.uuid));
        end
    end
`endif

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


endmodule
