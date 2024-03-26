class pcie_tl_base_test extends uvm_test;
  
  pcie_tl_env env;
  `uvm_component_utils(pcie_tl_base_test);

  `NEW_COMP

  function void build_phase(uvm_phase phase);
    env = pcie_tl_env::type_id::create("env",this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction


  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    #10000;
    phase.drop_objection(this);
  endtask

  function void report_phase(uvm_phase phase);
    if (pcie_common:: num_tx_matches > 0 && pcie_common::num_tx_matches == 0) begin
      `uvm_info("STATUS",$psprintf("TEST PASSED, num_tx_matches=%0d",pcie_common::num_tx_matches),UVM_NONE);
    end else begin
      `uvm_error("STATUS",$psprintf("TEST FAILED, num_tx_matches=%0d num_tx_mismatches=%0d",pcie_common::num_tx_matches,pcie_common::num_tx_mismatches));
    end

    if (pcie_common:: num_rx_matches > 0 && pcie_common::num_rx_matches == 0) begin
      `uvm_info("STATUS",$psprintf("TEST PASSED, num_rx_matches=%0d",pcie_common::num_rx_matches),UVM_NONE);
    end else begin
      `uvm_error("STATUS",$psprintf("TEST FAILED, num_rx_matches=%0d num_rx_mismatches=%0d",pcie_common::num_rx_matches,pcie_common::num_rx_mismatches));
    end

    if (pcie_common:: num_tx_rx_matches > 0 && pcie_common::num_tx_rx_matches == 0) begin
      `uvm_info("STATUS",$psprintf("TEST PASSED, num_tx_rx_matches=%0d",pcie_common::num_tx_rx_matches),UVM_NONE);
    end else begin
      `uvm_error("STATUS",$psprintf("TEST FAILED, num_tx_rx_matches=%0d num_tx_rx_mismatches=%0d",pcie_common::num_tx_rx_matches,pcie_common::num_tx_rx_mismatches));
    end

  endfunction
endclass

class pcie_wr_rd_test extends pcie_tl_base_test;

  `uvm_component_utils(pcie_wr_rd_test);
  `NEW_COMP

  task run_phase(uvm_phase phase);
    axi_config_seq config_seq;
    axi_dma_descr_load_seq dma_load_seq;
    axi_mem_wr_cfg_seq mem_wr_seq;

    dll_linkup_indicate_seq dll_link_seq;
    dll_vc_up_indicate_seq dll_vc_seq;
    dll_cpl_seq dll_cpl;

    config_seq = axi_config_seq::type_id::create("config_seq");
    dma_load_seq = axi_dma_descr_load_seq::type_id::create("dma_load_seq");
    mem_wr_seq = axi_mem_wr_cfg_seq::type_id::create("mem_wr_seq");

    dll_link_seq = dll_linkup_indicate_seq::type_id::create("dll_link_seq");
    dll_vc_seq = dll_vc_up_indicate_seq::type_id::create("dll_vc_seq");
    dll_cpl = dll_cpl_seq::type_id::create("dll_cpl");


    phase.phase_done.set_drain_time(this, 5);
        
    phase.raise_objection(this);
    dma_load_seq.start(env.axi_agent_i.sqr);
    config_seq.start(env.axi_agent_i.sqr);
    dll_link_seq.start(env.dll_rx_agent_i.sqr);
    dll_vc_seq.start(env.dll_rx_agent_i.sqr);
    fork
      dll_cpl.start(env.dll_rx_agent_i.sqr); // because a forever loop is present here
    join_none

    $display("######### Start Mem Write Seq ############");
    mem_wr_seq.start(env.axi_agent_i.sqr);
    phase.drop_objection(this);
    
  endtask


endclass