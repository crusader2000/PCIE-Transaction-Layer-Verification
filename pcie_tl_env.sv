class pcie_tl_env extends uvm_test;

  axi_agent axi_agent_i;
  mem_agent mem_agent_i;
  dll_tx_agent dll_tx_agent_i;
  dll_rx_agent dll_rx_agent_i;
  tl_sbd tl_sbd_i; // scoreboard

  `uvm_component_utils(pcie_tl_env);
  
  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction //new()

  function void build_phase(uvm_phase phase);
    axi_agent_i = axi_agent::type_id::create("axi_agent_i",this);
    mem_agent_i = mem_agent::type_id::create("mem_agent_i",this);
    dll_tx_agent_i = dll_tx_agent::type_id::create("dll_tx_agent_i",this);
    dll_rx_agent_i = dll_rx_agent::type_id::create("dll_agent_rx_i",this);
    tl_sbd_i    = tl_sbd::type_id::create("tl_sbd_i",this);
  endfunction

  function void connect_phase(uvm_phase phase);
    dll_tx_agent_i.mon.ap_port.connect(tl_sbd_i.imp_dll_tx);
    dll_rx_agent_i.mon.ap_port.connect(tl_sbd_i.imp_dll_rx);
    axi_agent_i.mon.ap_port.connect(tl_sbd_i.imp_proc);
    mem_agent_i.mon.ap_port.connect(tl_sbd_i.imp_mem);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    #1000;
    phase.drop_objection(this);
  endtask
endclass