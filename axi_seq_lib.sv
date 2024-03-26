class axi_base_seq extends uvm_sequence#(axi_tx);
  `uvm_object_utils(axi_base_seq)
  `NEW_OBJ

  task pre_body();
    uvm_phase phase = get_starting_phase();
    if (phase != null) begin
      phase.phase_done.set_drain_time(this, 100);
      phase.raise_objection(this);
    end
  endtask
  task post_body();
    uvm_phase phase = get_starting_phase();
    if (phase != null) begin
      phase.drop_objection(this);
    end
  endtask
endclass

class axi_config_seq extends axi_base_seq;
  axi_tx tx;
  axi_tx txQ[$];
  `uvm_object_utils(axi_config_seq)
  `NEW_OBJ

  task body();
    for (int i = 0; i < 2; i++) begin
      req = new();
      `uvm_do_with(req, {req.wr_rd==1; req.burst_len == 0; req.addr == 32'h1000+4*i; req.dataQ[0][0]==1'b0;}) //WR tx
      // tx = new req; //
      txQ.push_back(req);
    end
    //100C : ep_bar0_base_addr
    `uvm_do_with(req, {req.wr_rd==1; req.burst_len == 0; req.addr == 32'h100C; req.dataQ[0] ==32'hEC00_0000;})
    //1018
    `uvm_do_with(req, {req.wr_rd==1; req.burst_len == 0; req.addr == 32'h1018; req.dataQ[0] == `PAYLOAD_SIZE;})
    //101C
//     `uvm_do_with(req, {req.wr_rd==1; req.burst_len == 0; req.addr == 32'h101C; req.dataQ[0] == 32'h1;})
    //Reading back same registers
    for (int i = 0; i < 2; i++) begin
      tx = txQ.pop_front();
      `uvm_do_with(req, {
              req.wr_rd==0; 
              req.addr == tx.addr; 
              req.burst_size == tx.burst_size; 
              req.burst_type == tx.burst_type;}) //RD tx
    end
    `uvm_do_with(req, {req.wr_rd==1; req.addr == 32'h1004; req.dataQ[0][0]==1'b1;}) //Done with write-read of registers, now move to Link-training
  endtask
endclass

class axi_dma_descr_load_seq extends axi_base_seq;
  axi_tx tx;
  axi_tx txQ[$];
  `uvm_object_utils(axi_dma_descr_load_seq)
  `NEW_OBJ

  task body();
  bit [15:0] length;
  bit [31:0] data_t;
    //loading transmit descritprs
    `uvm_do_with(req, {req.wr_rd==1; req.burst_len == 0; req.addr == 32'h2004; req.dataQ[0]==32'h8000_0000;}) //addr from where DMA should perform read
    length = `PAYLOAD_SIZE; //bytes
    data_t = {length, 1'b1, 1'b1, 1'b1, 13'b0};
    `uvm_do_with(req, {req.wr_rd==1; req.burst_len == 0;req.addr == 32'h2000; req.dataQ[0]==data_t;})

    //loading receive descritprs
    `uvm_do_with(req, {req.wr_rd==1; req.burst_len == 0; req.addr == 32'h2804; req.dataQ[0]==32'h8800_0000;}) 
    length = `PAYLOAD_SIZE; //bytes
    data_t = {length, 1'b1, 1'b1, 1'b1, 13'b0};
    `uvm_do_with(req, {req.wr_rd==1; req.burst_len == 0; req.addr == 32'h2800; req.dataQ[0]==data_t;})
  endtask
endclass

class axi_mem_wr_cfg_seq extends axi_base_seq;
  `uvm_object_utils(axi_mem_wr_cfg_seq)
  `NEW_OBJ

  task body();
//   repeat(3) begin
    wait (pcie_common::pcie_tl_dll_state == 5'h14); //wait for Enumeration to complete
    `uvm_do_with(req, {req.wr_rd==1; req.burst_len == 0; req.addr == 32'h1014; req.dataQ[0][4:0]==`MEM_WR;})
    `uvm_do_with(req, {req.wr_rd==1; req.burst_len == 0; req.addr == 32'h1010; req.dataQ[0]==32'b1;})

//   end
//   repeat(3) begin
    wait (pcie_common::pcie_tl_dll_state == 5'h14); //Wait for MEM_WR to complete
    `uvm_do_with(req, {req.wr_rd==1; req.burst_len == 0; req.addr == 32'h1014; req.dataQ[0][4:0]==`MEM_RD;})
    `uvm_do_with(req, {req.wr_rd==1; req.burst_len == 0; req.addr == 32'h1010; req.dataQ[0]==32'b1;})
//   end
  endtask
endclass