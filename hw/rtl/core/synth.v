/* Generated by Yosys 0.45+139 (git sha1 4d581a97d, clang++ 11.0.1-2 -fPIC -O3) */

(* hdlname = "VX_fetch" *)
(* top =  1  *)
(* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:1.1-67.10" *)
module VX_fetch(clk, reset);
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:6.20-6.23" *)
  input clk;
  wire clk;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:65.16-65.34" *)
  wire \fetch_if.data.uuid ;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:37.14-37.24" *)
  wire ibuf_ready;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:56.16-56.44" *)
  wire \icache_bus_if.req_data.atype ;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:58.16-58.45" *)
  wire \icache_bus_if.req_data.byteen ;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:59.16-59.43" *)
  wire \icache_bus_if.req_data.data ;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:57.16-57.41" *)
  wire \icache_bus_if.req_data.rw ;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:11.21-11.36" *)
  wire [29:0] icache_req_addr;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:14.21-14.35" *)
  (* unused_bits = "0 2" *)
  wire [45:0] icache_req_tag;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:17.20-17.27" *)
  (* unused_bits = "0" *)
  wire [1:0] req_tag;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:7.20-7.25" *)
  input reset;
  wire reset;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:18.20-18.27" *)
  (* unused_bits = "0" *)
  wire [1:0] rsp_tag;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:16.21-16.29" *)
  wire [43:0] rsp_uuid;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:40.34-40.55" *)
  (* unused_bits = "0" *)
  wire \schedule_if.data.uuid ;
  (* src = "/home/sallyjunsongwang/vortex/hw/rtl/core/VX_fetch.v:20.26-20.46" *)
  (* unused_bits = "0" *)
  wire \schedule_if.data.wid ;
  assign \fetch_if.data.uuid  = 1'h0;
  assign ibuf_ready = 1'h1;
  assign \icache_bus_if.req_data.atype  = 1'h0;
  assign \icache_bus_if.req_data.byteen  = 1'h1;
  assign \icache_bus_if.req_data.data  = 1'h0;
  assign \icache_bus_if.req_data.rw  = 1'h0;
  assign icache_req_addr = 30'hxxxxxxxx;
  assign { icache_req_tag[45:3], icache_req_tag[1] } = 44'h00000000000;
  assign req_tag = { 1'h0, icache_req_tag[0] };
  assign rsp_tag[1] = 1'h0;
  assign rsp_uuid = 44'h00000000000;
  assign \schedule_if.data.uuid  = icache_req_tag[2];
  assign \schedule_if.data.wid  = icache_req_tag[0];
endmodule
