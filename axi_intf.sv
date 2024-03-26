interface axi_intf(input bit aclk,arst);


bit awvalid, awready;
bit wvalid, wready;
bit [3:0] awid;
bit [31:0] awaddr;
bit [3:0] awlen;
bit [1:0] awburst;
bit [2:0] awsize;
bit [31:0] wdata;
bit [3:0] wstrb;
bit [3:0] wid;
bit wlast;
bit bvalid;
bit bready;
bit [1:0] bid;
bit [1:0] bresp;

bit arvalid, arready;
bit rvalid, rready;
bit [3:0] arid;
bit [31:0] araddr;
bit [3:0] arlen;
bit [1:0] arburst;
bit [2:0] arsize;
bit [31:0] rdata;
bit [3:0] rid;
bit rlast;
bit [1:0] rresp;

clocking bfm_cb@(posedge aclk);
default input #0 output #0;
output awid, awaddr, awlen, awsize, awburst, awvalid;
input arst, awready, wready;
output wid, wdata, wstrb, wlast, wvalid;
input bid,bresp,bvalid;
output bready;

output arid, araddr, arlen, arsize, arburst, arvalid;
input arready;
input rid, rdata, rlast, rvalid, rresp;
output rready;
endclocking


clocking mon_cb@(posedge aclk);
default input #0 output #0;
input awid, awaddr, awlen, awsize, awburst, awvalid;
input arst;
input awready, wready;
input wid, wdata, wstrb, wlast, wvalid;
input bid,bresp,bvalid;
input bready;

input arid, araddr, arlen, arsize, arburst, arvalid;
input arready;
input rid, rdata, rlast, rvalid, rresp;
input rready;
endclocking


endinterface