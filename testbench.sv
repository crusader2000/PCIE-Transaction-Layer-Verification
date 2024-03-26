`include "uvm_pkg.sv";
import uvm_pkg::*;

// `include "pcie_common.sv"
`include "axi_intf.sv";
`include "tl_dll_intf.sv";

`include "axi_agent.sv";
`include "dll_agent.sv";
`include "mem_agent.sv";

`include "axi_seq_lib.sv";
`include "dll_rx_seq_lib.sv";

`include "tl_sbd.sv";
`include "pcie_tl_env.sv";
`include "test_lib.sv";

// `include "pcie_tl.sv";


module top_tb;

reg aclk, arst, tl_dll_clk;
axi_intf axi_p_pif(aclk,arst);
axi_intf axi_m_pif(aclk,arst);
  
tl_dll_intf tl_dll_pif(tl_dll_clk,arst);
  
initial begin
  aclk = 0;
  forever #0.5 aclk = ~aclk;
end

initial begin
  tl_dll_clk = 0;
  forever #0.5 tl_dll_clk = ~tl_dll_clk;
end

initial begin
  arst = 1;
  repeat(2) @(posedge aclk);
  arst = 0;
end

initial begin
  uvm_resource_db#(virtual axi_intf)::set("AXI","VIF",axi_p_pif,null);
  uvm_resource_db#(virtual axi_intf)::set("AXI","MIF",axi_m_pif,null);
  uvm_resource_db#(virtual tl_dll_intf)::set("DLL","VIF",tl_dll_pif,null);
end


pcie_tl dut(
  .aclk(aclk),
  .arst(arst),
  
  // processor
  .awvalid_p(axi_p_pif.awvalid),
  .awready_p(axi_p_pif.awready),
  .awid_p(axi_p_pif.awid),
  .awaddr_p(axi_p_pif.awaddr),
  .awlen_p(axi_p_pif.awlen),
  .awburst_p(axi_p_pif.awburst),
  .awsize_p(axi_p_pif.awsize),
  .wvalid_p(axi_p_pif.wvalid),
  .wready_p(axi_p_pif.wready),
  .wdata_p(axi_p_pif.wdata),
  .wstrb_p(axi_p_pif.wstrb),
  .wid_p(axi_p_pif.wid),
  .wlast_p(axi_p_pif.wlast),
  .bvalid_p(axi_p_pif.bvalid),
  .bready_p(axi_p_pif.bready),
  .bid_p(axi_p_pif.bid),
  .bresp_p(axi_p_pif.bresp),

  .arvalid_p(axi_p_pif.arvalid),
  .arready_p(axi_p_pif.arready),
  .arid_p(axi_p_pif.arid),
  .araddr_p(axi_p_pif.araddr),
  .arlen_p(axi_p_pif.arlen),
  .arburst_p(axi_p_pif.arburst),
  .arsize_p(axi_p_pif.arsize),
  .rvalid_p(axi_p_pif.rvalid),
  .rready_p(axi_p_pif.rready),
  .rdata_p(axi_p_pif.rdata),
  .rid_p(axi_p_pif.rid),
  .rlast_p(axi_p_pif.rlast),
  .rresp_p(axi_p_pif.rresp),


  // memory
  .awvalid_m(axi_m_pif.awvalid),
  .awready_m(axi_m_pif.awready),
  .awid_m(axi_m_pif.awid),
  .awaddr_m(axi_m_pif.awaddr),
  .awlen_m(axi_m_pif.awlen),
  .awburst_m(axi_m_pif.awburst),
  .awsize_m(axi_m_pif.awsize),
  .wvalid_m(axi_m_pif.wvalid),
  .wready_m(axi_m_pif.wready),
  .wdata_m(axi_m_pif.wdata),
  .wstrb_m(axi_m_pif.wstrb),
  .wid_m(axi_m_pif.wid),
  .wlast_m(axi_m_pif.wlast),
  .bvalid_m(axi_m_pif.bvalid),
  .bready_m(axi_m_pif.bready),
  .bid_m(axi_m_pif.bid),
  .bresp_m(axi_m_pif.bresp),
  
  .arvalid_m(axi_m_pif.arvalid),
  .arready_m(axi_m_pif.arready),
  .arid_m(axi_m_pif.arid),
  .araddr_m(axi_m_pif.araddr),
  .arlen_m(axi_m_pif.arlen),
  .arburst_m(axi_m_pif.arburst),
  .arsize_m(axi_m_pif.arsize),
  .rvalid_m(axi_m_pif.rvalid),
  .rready_m(axi_m_pif.rready),
  .rdata_m(axi_m_pif.rdata),
  .rid_m(axi_m_pif.rid),
  .rlast_m(axi_m_pif.rlast),
  .rresp_m(axi_m_pif.rresp),

  // DLL_TX
  .tl_dll_clk(tl_dll_clk),
  .tx_data_o(tl_dll_pif.tx_data_o),
  .tx_valid_o(tl_dll_pif.tx_valid_o),
  .tx_ready_i(tl_dll_pif.tx_ready_i),
  .vc_num(tl_dll_pif.vc_num),
  
  // DLL_RX
  .rx_data_i(tl_dll_pif.rx_data_i),
  .rx_valid_i(tl_dll_pif.rx_valid_i),
  .rx_ready_o(tl_dll_pif.rx_ready_o),
  .dll_vc_up(tl_dll_pif.dll_vc_up),
  .linkup(tl_dll_pif.linkup)
);

initial begin
  $dumpfile("dump.vcd");
  $dumpvars(0,top_tb);

  dll_cfg_rx::vip_cfg_as_ep(); // it is going to set the variables as EP
  
  run_test("pcie_wr_rd_test");
end  

always @(dut.n_state_dll) begin
  pcie_common::pcie_tl_dll_state  = dut.n_state_dll;
end
// initial begin
//   #3000;
//   $finish;
// end

endmodule