class memory extends uvm_component; //uvm_driver#(axi_tx);
  bit [3:0] arid_t;
  bit [31:0] araddr_t;
  bit [3:0] arlen_t;
  bit [1:0] arburst_t;
  bit [1:0] arsize_t;

  bit [3:0] awid_t;
  bit [31:0] awaddr_t;
  bit [3:0] awlen_t;
  bit [1:0] awburst_t;
  bit [1:0] awsize_t;
  virtual axi_intf vif;
  bit [31:0] offset;
  byte mem[1024*1024-1:0]; //1MB, base addr: 8000_0000
    //1MB addr: 20-0's
    //20'h0_0000 to 20'hF_FFFF => 1MB
  `uvm_component_utils(memory)
  `NEW_COMP

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_resource_db#(virtual axi_intf)::read_by_name("AXI", "MIF", vif, this);
  endfunction

  function void start_of_simulation_phase(uvm_phase phase);
    offset = 32'h8000_0000;
    for (int i = 0; i < 1024*1024; i++) begin
      mem[i] = $random;
    end
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.aclk);
      if (vif.arvalid == 1) begin
        vif.arready = 1;
        araddr_t = vif.araddr;
        arlen_t = vif.arlen;
        arid_t = vif.arid;
        arburst_t = vif.arburst;
        arsize_t = vif.arsize;
        fork
        drive_read_data();
        @(posedge vif.aclk) vif.arready = 0;
        join
      end
      if (vif.awvalid == 1) begin
        vif.awready = 1;
        awaddr_t = vif.awaddr;
        awlen_t = vif.awlen;
        awid_t = vif.awid;
        awburst_t = vif.awburst;
        awsize_t = vif.awsize;
      end
      else begin
        vif.awready = 0;
      end
      if (vif.wvalid == 1) begin
        vif.wready = 1;
        mem[awaddr_t] = vif.wdata[7:0];
        mem[awaddr_t+1] = vif.wdata[15:8];
        mem[awaddr_t+2] = vif.wdata[23:16];
        mem[awaddr_t+3] = vif.wdata[31:24];
        awaddr_t += 4;
        if (vif.wlast == 1) begin
          fork
            do_write_resp();
            @(posedge vif.aclk) vif.wready = 0;
          join
        end
      end
      else begin
        vif.wready = 0;
      end
    end
  endtask

  task do_write_resp();
    @(posedge vif.aclk);
    vif.bid = 0;
    vif.bvalid = 1;
    vif.bresp = 2'b0;
    wait (vif.bready == 1);
    @(posedge vif.aclk);
    vif.bvalid = 0;
  endtask

  task drive_read_data();
    for (int j = 0; j <= arlen_t; j++) begin
      @(posedge vif.aclk);
      vif.rdata = {
        mem[araddr_t-offset+3],
        mem[araddr_t-offset+2],
        mem[araddr_t-offset+1],
        mem[araddr_t-offset+0]
      };
      vif.rid = arid_t;
      vif.rresp = 2'b00; //OKAY
      vif.rvalid = 1'b1;
      if (j == arlen_t) vif.rlast = 1;
      wait (vif.rready == 1);
      araddr_t = araddr_t + 4;
    end
    @(posedge vif.aclk);
    vif.rdata = 0;
    vif.rid = 0;
    vif.rvalid = 0;
    vif.rlast = 0;
  endtask
endclass

class mem_mon extends uvm_monitor;

  virtual axi_intf vif;
  axi_tx tx;
  uvm_analysis_port#(axi_tx) ap_port;
  `uvm_component_utils(mem_mon)
  `NEW_COMP

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_resource_db#(virtual axi_intf)::read_by_name("AXI","MIF", vif, this)) begin
      `uvm_error("RESOURCE_DB_ERROR", "Not able to retrive mem_vif")
    end
    ap_port = new("ap_port",this);
  endfunction

  task run_phase(uvm_phase phase);
    bit ignore_first_dw_f;
    
    wait (vif.mon_cb.arst == 0);
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.awvalid && vif.mon_cb.awready) begin
        tx = axi_tx::type_id::create("tx");
        tx.wr_rd = 1'b1;
        tx.txid = vif.mon_cb.awid;
        tx.addr = vif.mon_cb.awaddr;
        tx.burst_len = vif.mon_cb.awlen;
        tx.burst_type = burst_type_t'(vif.mon_cb.awburst);
        tx.burst_size = vif.mon_cb.awsize;
        ignore_first_dw_f = 1;
        $display("MEM_MON - Completed write address phase");
      end

      if (vif.mon_cb.wvalid && vif.mon_cb.wready) begin
        if (ignore_first_dw_f == 1) begin
          ignore_first_dw_f = 0;
        end else begin
          tx.dataQ.push_back(vif.mon_cb.wdata);
          tx.strbQ.push_back(vif.mon_cb.wstrb);
          $display("MEM_MON - Completed write data phase");
        end
      end

      if (vif.mon_cb.bvalid && vif.mon_cb.bready) begin
        tx.resp = vif.mon_cb.bresp;

        ap_port.write(tx);
        $display("MEM_MON - Completed write response phase");
        $display("%t : Collected write axi_data at mem_mon",$time);

        tx.print();
      end
      
      if (vif.mon_cb.arvalid && vif.mon_cb.arready) begin
        tx = axi_tx::type_id::create("tx");
        tx.wr_rd = 1'b0;
        tx.txid = vif.mon_cb.arid;
        tx.addr = vif.mon_cb.araddr;
        tx.burst_len = vif.mon_cb.arlen;
        tx.burst_type = vif.mon_cb.arburst;
        tx.burst_size = vif.mon_cb.arsize;
        $display("MEM_MON - Completed read address phase");
      end

      if (vif.mon_cb.rvalid && vif.mon_cb.rready) begin
        tx.dataQ.push_back(vif.mon_cb.rdata);
        tx.resp = vif.mon_cb.rresp;
        if (vif.mon_cb.rlast == 1) begin
          ap_port.write(tx);
        end
        $display("MEM_MON - Completed read data phase");
        $display("%t : Collected read axi_data at mem_mon",$time);

        tx.print();
      end
    end
  endtask



endclass

class mem_agent extends uvm_test;

  memory mem;
  mem_mon mon;

  `uvm_component_utils(mem_agent);
  
  `NEW_COMP

  function void build_phase(uvm_phase phase);
    mem = memory::type_id::create("mem",this);
    mon = mem_mon::type_id::create("mon",this);
  endfunction

endclass