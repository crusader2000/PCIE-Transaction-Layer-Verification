`uvm_analysis_imp_decl(_dll_tx)
`uvm_analysis_imp_decl(_dll_rx)
`uvm_analysis_imp_decl(_proc)
`uvm_analysis_imp_decl(_mem)

class tl_sbd extends uvm_scoreboard;
  
  uvm_analysis_imp_dll_tx#(dll_item,tl_sbd) imp_dll_tx;
  uvm_analysis_imp_dll_rx#(dll_item,tl_sbd) imp_dll_rx;
  uvm_analysis_imp_proc#(axi_tx,tl_sbd) imp_proc;
  uvm_analysis_imp_mem#(axi_tx,tl_sbd) imp_mem;

  `uvm_component_utils(tl_sbd);
  `NEW_COMP

  byte mem_rdAA[int];
  byte tlp_txAA[int];
  byte mem_wrAA[int];
  byte tlp_rxAA[int];


  byte mem_rdQ[$];
  byte mem_wrQ[$];
  byte tlp_txQ[$];
  byte tlp_rxQ[$];
  byte tlp_txQ_b[$];
  byte tlp_rxQ_b[$];


  byte mem_rd_byte;
  byte mem_wr_byte;
  byte tlp_tx_byte;
  byte tlp_rx_byte;
  byte tlp_tx_b;
  byte tlp_rx_b;

  function void build_phase(uvm_phase phase);
    imp_dll_tx = new("imp_dll_tx",this);
    imp_dll_rx = new("imp_dll_rx",this);
    imp_proc = new("imp_proc",this);
    imp_mem = new("imp_mem",this);
  endfunction

  function void write_dll_tx(dll_item tlp_tx_pkt);

    foreach (tlp_tx_pkt.payloadQ[i]) begin
      tlp_txQ.push_back(tlp_tx_pkt.payloadQ[i][7:0]);
      tlp_txQ.push_back(tlp_tx_pkt.payloadQ[i][15:8]);
      tlp_txQ.push_back(tlp_tx_pkt.payloadQ[i][23:16]);
      tlp_txQ.push_back(tlp_tx_pkt.payloadQ[i][31:24]);

      tlp_txQ_b.push_back(tlp_tx_pkt.payloadQ[i][7:0]);
      tlp_txQ_b.push_back(tlp_tx_pkt.payloadQ[i][15:8]);
      tlp_txQ_b.push_back(tlp_tx_pkt.payloadQ[i][23:16]);
      tlp_txQ_b.push_back(tlp_tx_pkt.payloadQ[i][31:24]);
    end

  endfunction

  function void write_dll_rx(dll_item tlp_rx_pkt);
    
    foreach (tlp_rx_pkt.payloadQ[i]) begin
      tlp_rxQ.push_back(tlp_rx_pkt.payloadQ[i][7:0]);
      tlp_rxQ.push_back(tlp_rx_pkt.payloadQ[i][15:8]);
      tlp_rxQ.push_back(tlp_rx_pkt.payloadQ[i][23:16]);
      tlp_rxQ.push_back(tlp_rx_pkt.payloadQ[i][31:24]);

      tlp_rxQ_b.push_back(tlp_rx_pkt.payloadQ[i][7:0]);
      tlp_rxQ_b.push_back(tlp_rx_pkt.payloadQ[i][15:8]);
      tlp_rxQ_b.push_back(tlp_rx_pkt.payloadQ[i][23:16]);
      tlp_rxQ_b.push_back(tlp_rx_pkt.payloadQ[i][31:24]);
    end

  endfunction

  function void write_proc(axi_tx proc_tx);
    
  endfunction

  function void write_mem(axi_tx mem_tx);
    if (mem_tx.wr_rd == 1'b1) begin

      foreach (mem_tx.dataQ[i]) begin
        mem_wrQ.push_back(mem_tx.dataQ[i][7:0]);
        mem_wrQ.push_back(mem_tx.dataQ[i][15:8]);
        mem_wrQ.push_back(mem_tx.dataQ[i][23:16]);
        mem_wrQ.push_back(mem_tx.dataQ[i][31:24]);
        // mem_wrAA[mem_tx.addr] = mem_tx.dataQ[i][7:0];
        // mem_wrAA[mem_tx.addr+1] = mem_tx.dataQ[i][15:8];
        // mem_wrAA[mem_tx.addr+2] = mem_tx.dataQ[i][23:16];
        // mem_wrAA[mem_tx.addr+31] = mem_tx.dataQ[i][31:24];
      end

    end else begin

      foreach (mem_tx.dataQ[i]) begin
        mem_rdQ.push_back(mem_tx.dataQ[i][7:0]);
        mem_rdQ.push_back(mem_tx.dataQ[i][15:8]);
        mem_rdQ.push_back(mem_tx.dataQ[i][23:16]);
        mem_rdQ.push_back(mem_tx.dataQ[i][31:24]);
      end

    end
    
  endfunction

  task run_phase(uvm_phase phase);
    fork
      forever begin
        wait (mem_rdQ.size() > 0 && tlp_txQ.size() > 0);
      
        mem_rd_byte = mem_rdQ.pop_front();
        tlp_tx_byte = tlp_txQ.pop_front();

        if (mem_rd_byte == tlp_tx_byte) begin
          pcie_common::num_tx_matches++;
        end else begin
          pcie_common::num_tx_mismatches++;
        end

      end
      forever begin
        wait (mem_wrQ.size() > 0 && tlp_rxQ.size() > 0);
      
        mem_wr_byte = mem_wrQ.pop_front();
        tlp_tx_byte = tlp_rxQ.pop_front();

        if (mem_wr_byte == tlp_tx_byte) begin
          pcie_common::num_rx_matches++;
        end else begin
          pcie_common::num_rx_mismatches++;
        end

      end
      forever begin
        wait (tlp_txQ_b.size() > 0 && tlp_rxQ_b.size() > 0);
      
        tlp_rx_b = tlp_txQ_b.pop_front();
        tlp_tx_b = tlp_rxQ_b.pop_front();

        if (tlp_rx_b == tlp_tx_b) begin
          pcie_common::num_tx_rx_matches++;
        end else begin
          pcie_common::num_tx_rx_mismatches++;
        end

      end

    join

  endtask

endclass