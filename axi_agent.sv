class axi_tx extends uvm_sequence_item;
  rand bit [3:0] txid;
  rand bit [31:0] addr;
  rand bit [31:0] dataQ[$];
  rand bit [31:0] strbQ[$];
  rand bit wr_rd;
  rand bit [3:0] burst_len; // 0->1 beat, 1-> 2 beats, so on
  rand burst_type_t burst_type;
  rand bit [2:0] burst_size;
  // rand lock_t lock;
  rand bit [1:0] resp;
  // valid => handshaking signals should never be party of tx
//   prot,cache,lock

  `uvm_object_utils_begin(axi_tx)
    `uvm_field_int(txid,UVM_ALL_ON)
    `uvm_field_int(addr,UVM_ALL_ON)
    `uvm_field_queue_int(dataQ,UVM_ALL_ON)
    `uvm_field_queue_int(strbQ,UVM_ALL_ON)
    `uvm_field_int(wr_rd,UVM_ALL_ON)
    `uvm_field_int(burst_len,UVM_ALL_ON)
    `uvm_field_enum(burst_type_t,burst_type,UVM_ALL_ON)
    `uvm_field_int(burst_size,UVM_ALL_ON)
    // // `uvm_field_enum(lock_t,lock,UVM_ALL_ON)
    `uvm_field_int(resp,UVM_ALL_ON)

  `uvm_object_utils_end
  
  `NEW_OBJ // function new definition

  // constraints 
  constraint dataQ_c {
    dataQ.size() == burst_len + 1;
    strbQ.size() == burst_len + 1;
  }

  constraint rsvd_c {
    burst_type != RSVD_BT;
    // lock != RSVD_LK;
  }

  constraint soft_c {
    soft burst_type == INCR; // default tx type
    soft burst_size == 2; // 4 bytes per beat
    soft burst_len == 1; // 1 beat per tx
    // soft lock == NORMAL; // 4 bytes per beat
    soft addr%4 == 0; // Tx is 32 bit aligned
    soft wr_rd == 1;
  }
endclass

//////////////////////////////////////////////////

class axi_drv extends uvm_driver#(axi_tx);
  virtual axi_intf vif;
  `uvm_component_utils(axi_drv)
  `NEW_COMP

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_resource_db#(virtual axi_intf)::read_by_type("AXI", vif, this)) begin
      `uvm_error("RESOURCE_DB_ERROR", "Not able to retrive axi_vif")
    end
  endfunction

  task run_phase(uvm_phase phase);
    wait (vif.bfm_cb.arst == 0);
    forever begin
      seq_item_port.get_next_item(req);
      drive_tx(req); //drive the AHB interface with this request
      seq_item_port.item_done();  //I am done with this item
    end
  endtask

  //AXI timing diagram is implemented
  task drive_tx(axi_tx tx);
  if (tx.wr_rd == 1) begin
    write_addr(tx);
    write_data(tx);
    write_resp(tx);
  end
  else begin
    read_addr(tx);
    read_data(tx);
  end
  endtask

  task write_addr(axi_tx tx);
    `uvm_info("AXI_WR", "write_addr", UVM_LOW)
    @(vif.bfm_cb);
    vif.bfm_cb.awvalid <= 1;
    vif.bfm_cb.awaddr <= tx.addr;
    vif.bfm_cb.awlen <= tx.burst_len;
    vif.bfm_cb.awsize <= tx.burst_size;
    vif.bfm_cb.awburst <= tx.burst_type;
    vif.bfm_cb.awid <= tx.txid;
    wait (vif.bfm_cb.awready == 1);
    @(vif.bfm_cb);
    vif.bfm_cb.awvalid <= 0;
    vif.bfm_cb.awaddr <= 0;
    vif.bfm_cb.awlen <= 0;
    vif.bfm_cb.awsize <= 0;
    vif.bfm_cb.awburst <= 0;
    vif.bfm_cb.awid <= 0;
  endtask
  task write_data(axi_tx tx);
    `uvm_info("AXI_WR", "write_data", UVM_LOW)
    for (int i = 0; i < tx.burst_len+1; i++) begin
      @(vif.bfm_cb);
      vif.bfm_cb.wid <= tx.txid;
      vif.bfm_cb.wdata <= tx.dataQ.pop_front();
      vif.bfm_cb.wstrb <= tx.strbQ.pop_front();
      vif.bfm_cb.wvalid <= 1;
      if (i == tx.burst_len) vif.bfm_cb.wlast <= 1'b1;
      wait (vif.bfm_cb.wready == 1);
    end
      @(vif.bfm_cb);
      vif.bfm_cb.wid <= 0;
      vif.bfm_cb.wdata <= 0;
      vif.bfm_cb.wstrb <= 0;
      vif.bfm_cb.wvalid <= 0;
      vif.bfm_cb.wlast <= 1'b0;
  endtask

  task write_resp(axi_tx tx);
    `uvm_info("AXI_WR", "write_resp", UVM_LOW)
    while (vif.bfm_cb.bvalid == 1'b0) begin
      @(vif.bfm_cb);
    end
    vif.bfm_cb.bready <= 1;
    @(vif.bfm_cb);
    vif.bfm_cb.bready <= 0;
  endtask

  task read_addr(axi_tx tx);
    `uvm_info("AXI_RD", "read_addr", UVM_LOW)
    @(vif.bfm_cb);
    vif.bfm_cb.arvalid <= 1;
    vif.bfm_cb.araddr <= tx.addr;
    vif.bfm_cb.arlen <= tx.burst_len;
    vif.bfm_cb.arsize <= tx.burst_size;
    vif.bfm_cb.arburst <= tx.burst_type;
    vif.bfm_cb.arid <= tx.txid;
    wait (vif.bfm_cb.arready == 1);
    @(vif.bfm_cb);
    vif.bfm_cb.arvalid <= 0;
    vif.bfm_cb.araddr <= 0;
    vif.bfm_cb.arlen <= 0;
    vif.bfm_cb.arsize <= 0;
    vif.bfm_cb.arburst <= 0;
    vif.bfm_cb.arid <= 0;
  endtask

  task read_data(axi_tx tx);
  for (int i = 0; i <= tx.burst_len; i++) begin
    `uvm_info("AXI_RD", "read_data", UVM_LOW)
    @(vif.bfm_cb);
    vif.bfm_cb.rready <= 1;
    wait (vif.bfm_cb.rvalid == 1'b1);
  end
    @(vif.bfm_cb);
    @(vif.bfm_cb); //why this is required?
    vif.bfm_cb.rready <= 0;
    @(vif.bfm_cb); //wait 1 clock cycles before starting new tx
  endtask

  task set_default_values();
  endtask

endclass

//////////////////////////////////////////////////


typedef uvm_sequencer#(axi_tx) axi_sqr;

//////////////////////////////////////////////////

class axi_mon extends uvm_monitor;

  virtual axi_intf vif;
  axi_tx tx;
  uvm_analysis_port#(axi_tx) ap_port;
  `uvm_component_utils(axi_mon)
  `NEW_COMP

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_resource_db#(virtual axi_intf)::read_by_type("AXI", vif, this)) begin
      `uvm_error("RESOURCE_DB_ERROR", "Not able to retrive axi_vif")
    end
    ap_port = new("ap_port",this);
  endfunction

  task run_phase(uvm_phase phase);
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
        $display("%t : AXI_MON - Completed write address phase",$time);
      end

      if (vif.mon_cb.wvalid && vif.mon_cb.wready) begin
        tx.dataQ.push_back(vif.mon_cb.wdata);
        tx.strbQ.push_back(vif.mon_cb.wstrb);
        $display("%t : AXI_MON - Completed write data phase",$time);
      end

      if (vif.mon_cb.bvalid && vif.mon_cb.bready) begin
        tx.resp = vif.mon_cb.bresp;

        ap_port.write(tx);
        $display("%t : AXI_MON - Completed write response phase",$time);
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
      end

      if (vif.mon_cb.rvalid && vif.mon_cb.rready) begin
        tx.dataQ.push_back(vif.mon_cb.rdata);
        tx.resp = vif.mon_cb.rresp;
        if (vif.mon_cb.rlast == 1) begin
          ap_port.write(tx);
        end
      end
    end
  endtask



endclass


//////////////////////////////////////////////////

class axi_cov extends uvm_subscriber#(axi_tx);
  axi_tx tx;
  `uvm_component_utils(axi_cov);


  covergroup tl_axi_cg;
    PAYLOAD_SIZE_CP : coverpoint tx.dataQ[0] iff (tx.addr == 32'h1018) {
      bins PAYLOAD_SIZE_128 = {128};
      bins PAYLOAD_SIZE_256 = {256};
      bins PAYLOAD_SIZE_512 = {512};
      bins PAYLOAD_SIZE_1024 = {1024};
      bins PAYLOAD_SIZE_2048 = {2048};
      bins PAYLOAD_SIZE_4096 = {4096};
    }
  endgroup

  
  function new(string name, uvm_component parent);
    super.new(name,parent);
    tl_axi_cg = new();
  endfunction //new()

  function void write(axi_tx t);
    $cast (tx,t);
    tl_axi_cg.sample();
  endfunction

endclass

//////////////////////////////////////////////////

class axi_agent extends uvm_test;

  axi_drv drv;
  axi_sqr sqr;
  axi_mon mon;
  axi_cov cov;

  `uvm_component_utils(axi_agent);
  
  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction //new()

  function void build_phase(uvm_phase phase);
    drv = axi_drv::type_id::create("drv",this);
    sqr = axi_sqr::type_id::create("sqr",this);
    mon = axi_mon::type_id::create("mon",this);
    cov = axi_cov::type_id::create("cov",this);
  endfunction

  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
    mon.ap_port.connect(cov.analysis_export);
  endfunction

endclass
