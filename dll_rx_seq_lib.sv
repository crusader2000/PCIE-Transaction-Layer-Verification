class dll_rx_base_seq extends uvm_sequence#(dll_item);
  `uvm_object_utils(dll_rx_base_seq)
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

class dll_linkup_indicate_seq extends dll_rx_base_seq;
  dll_item tx;
  dll_item txQ[$];
  `uvm_object_utils(dll_linkup_indicate_seq)
  `NEW_OBJ

  task body();
    `uvm_do_with(req, {req.linkup_indicate==1'b1;}) // not generating any TLP
  endtask
endclass


class dll_vc_up_indicate_seq extends dll_rx_base_seq;
  dll_item tx;
  dll_item txQ[$];
  `uvm_object_utils(dll_vc_up_indicate_seq)
  `NEW_OBJ

  task body();
    `uvm_do_with(req, {req.vc_status_vector == 8'hFF;}) // not generating any TLP
  endtask
endclass

class dll_cpl_seq extends dll_rx_base_seq;
  `uvm_object_utils(dll_cpl_seq)
  `NEW_OBJ

  task body();
    forever begin
      // uvm_resource_db#(int)::read_by_name("TL","CFG",value,this); 
      @(pcie_common::rcvd_tlp_count);
      $display("=================== Driving CplD ============ %d",pcie_common::rcvd_tlp_count);
      fork
        `uvm_do_with(req, {req.tlp_type == pcie_common::transmit_tlp;}) // CplD
      join_none
    end
  endtask
endclass
