class dll_item extends uvm_sequence_item;
// represents the TLP => unit of communication between TL and DLL
  rand tlp_type_t tlp_type;
  int header_size;
  // header 
  rand bit [31:0] headerQ[$]; // 3DW or 4DW
  // payload
  rand bit [31:0] payloadQ[$]; // 0DW or 1024DW
  // digest
  rand bit [31:0] ecrc; 
  rand bit linkup_indicate;
  rand bit [7:0] vc_status_vector; 
  rand bit mem_data_f;

  // knobs : field that controls how other variables get randomized
  // knobs will not be driven on DUT interface

  `uvm_object_utils_begin(dll_item)
    `uvm_field_queue_int(headerQ,UVM_ALL_ON)
    `uvm_field_queue_int(payloadQ,UVM_ALL_ON)
    `uvm_field_int(ecrc,UVM_ALL_ON)
    `uvm_field_int(linkup_indicate,UVM_ALL_ON)
    `uvm_field_int(vc_status_vector,UVM_ALL_ON)

  `uvm_object_utils_end
  
  `NEW_OBJ // function new definition

  function void post_randomize();
    if (pcie_common::rcvd_tlp inside {CfgRd0,CfgRd1} && tlp_type == CplD) begin
      case (pcie_common::reg_num)
        0: payloadQ[0] = {dll_cfg_rx::device_id,dll_cfg_rx::vendor_id};
        1: payloadQ[0] = {dll_cfg_rx::status,dll_cfg_rx::command};
        2: payloadQ[0] = {dll_cfg_rx::class_code,dll_cfg_rx::revision_id};
        3: payloadQ[0] = {dll_cfg_rx::bist,dll_cfg_rx::vendor_id,dll_cfg_rx::latency_time,dll_cfg_rx::cache_line_size};
        4: payloadQ[0] = dll_cfg_rx::bar0;
        5: payloadQ[0] = dll_cfg_rx::bar1;
        6: payloadQ[0] = dll_cfg_rx::bar2;
        7: payloadQ[0] = dll_cfg_rx::bar3;
        8: payloadQ[0] = dll_cfg_rx::bar4;
        9: payloadQ[0] = dll_cfg_rx::bar5;
        10: payloadQ[0] = dll_cfg_rx::cardbus_cis_pointer;
        11: payloadQ[0] = {dll_cfg_rx::subsystem_id,dll_cfg_rx::subsystem_vendor_id};
        12: payloadQ[0] = dll_cfg_rx::expansion_rom_base_addr;
        13: payloadQ[0] = {24'h0,dll_cfg_rx::capability_pointer};
        14: payloadQ[0] = 32'h0;
        15: payloadQ[0] = {dll_cfg_rx::max_lat,dll_cfg_rx::min_gnt,dll_cfg_rx::interrupt_pin,dll_cfg_rx::interrupt_line};
      endcase
    end
  endfunction

  constraint soft_c {
    soft headerQ.size() == 3;
    soft payloadQ.size() == 1;
    soft linkup_indicate == 0;
    soft vc_status_vector == 0;
    soft mem_data_f == 0;
  }

  constraint header_c {
    (tlp_type == CplD) -> (
                              headerQ[0][31:29] == 3'b010 &&
                              headerQ[0][28:24] == 5'b01010 &&
                              headerQ[0][23] == pcie_common::tag[9] &&
                              headerQ[0][22:20] == pcie_common::tc &&
                              headerQ[0][19] == pcie_common::tag[8] &&
                              headerQ[0][18] == pcie_common::attr[2] &&
                              headerQ[0][17] == pcie_common::ln &&
                              headerQ[0][16] == pcie_common::th &&
                              headerQ[0][15] == pcie_common::td &&
                              headerQ[0][14] == pcie_common::ep &&
                              headerQ[0][13:12] == pcie_common::attr[1:0] &&
                              headerQ[0][11:10] == 2'b00 &&
                              headerQ[0][9:0] == 10'b1 &&

                              headerQ[1][31:16] == {pcie_common::target_bus_num,pcie_common::target_device_num,pcie_common::target_func_num} &&
                              headerQ[1][15:13] == 3'b000 &&
                              headerQ[1][12] == 0 &&
                              headerQ[1][11:0] == 0 &&

                              headerQ[2][31:16] == {pcie_common::requester_bus_num,pcie_common::requester_device_num,pcie_common::requester_func_num} &&
                              headerQ[2][15:8] == pcie_common::tag[7:0] &&
                              headerQ[2][7] == 0 &&
                              headerQ[2][6:0] == 0 &&

                              // payloadQ
                              payloadQ.size() == 1 &&
                              payloadQ[0] == 32'h1234_5678
                              
                            );
  }

endclass



//////////////////////////////////////////////////
typedef enum {
  S_IDLE_DUMMY,
  S_IDLE,
  S_TLP_FIRST_DW,
  S_TLP_SECOND_DW,
  S_TLP_THIRD_DW,
  S_TLP_PAYLOAD
} state_t;

class dll_tx_responder extends uvm_driver#(dll_item);
  virtual tl_dll_intf vif;
  state_t state,n_state;
  int header_size;
  int count;
  
  bit [31:0] tlp_first_dw,tlp_second_dw,tlp_third_dw;

  bit [31:0] rxdataQ[$];
  bit [31:0] payloadQ[$];

  `uvm_component_utils(dll_tx_responder)
  `NEW_COMP

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    state = S_IDLE_DUMMY;
    n_state = S_IDLE_DUMMY;
    if (!uvm_resource_db#(virtual tl_dll_intf)::read_by_type("DLL", vif, this)) begin
      `uvm_error("RESOURCE_DB_ERROR", "Not able to retrive axi_vif")
    end
  endfunction

  task run_phase(uvm_phase phase);
    // when TL DUT sends some TLP, I need to respond
    fork
      forever begin 
        @(n_state);
        state = n_state;
        // uvm_resource_db#(int)::("TL","STATE",state,this);
        pcie_common::state = state;
      end 
      forever begin
        @(posedge vif.tl_dll_clk);
        case (state)
          S_IDLE_DUMMY : begin
            if (vif.tx_valid_o == 1) begin
              n_state = S_IDLE;
            end
          end

          S_IDLE      : begin
            if (vif.tx_valid_o == 1) begin
              n_state = S_TLP_FIRST_DW;
            end
          end

          S_TLP_FIRST_DW : begin
            tlp_first_dw = vif.tx_data_o;
            $display("%t : tlp_first_dw = %h",$time,tlp_first_dw);
            // Header[0] field extract => Common for every TLP
            pcie_common::fmt = tlp_first_dw[31:29];
            pcie_common::type_t = tlp_first_dw[28:24];
            $display("%t : fmt = %b, type = %b",$time,pcie_common::fmt,pcie_common::type_t);

            header_size = 3; // Update Later

            pcie_common::tag[9]  = tlp_first_dw[23];
            pcie_common::tc  = tlp_first_dw[22:20];
            pcie_common::tag[8]  = tlp_first_dw[19];
            pcie_common::attr[2] = tlp_first_dw[18];
            pcie_common::ln = tlp_first_dw[17];
            pcie_common::th = tlp_first_dw[16];
            pcie_common::td = tlp_first_dw[15];
            pcie_common::ep = tlp_first_dw[14];
            pcie_common::attr[1:0] = tlp_first_dw[13:12];
            pcie_common::at = tlp_first_dw[11:10];
            pcie_common::packet_len = tlp_first_dw[9:0];
           $display("pcie_common::packet_len : %h",pcie_common::packet_len);
            if (vif.tx_valid_o == 1) begin
              n_state = S_TLP_SECOND_DW;
            end else begin
                n_state = S_IDLE;
            end
            
            $display("%t : S_TLP_FIRST_DW pcie_common::packet_len : %h",$time,pcie_common::packet_len);
          end

          S_TLP_SECOND_DW : begin
            tlp_second_dw = vif.tx_data_o;
            pcie_common::requester_bus_num = tlp_second_dw[31:24];
            pcie_common::requester_device_num = tlp_second_dw[23:19];
            pcie_common::requester_func_num = tlp_second_dw[18:16];
            pcie_common::tag[7:0] = tlp_second_dw[15:8];
            pcie_common::last_dw_be = tlp_second_dw[7:4];
            pcie_common::first_dw_be = tlp_second_dw[3:0];
           $display("pcie_common::packet_len : %h",pcie_common::packet_len);

            if (vif.tx_valid_o == 1) begin
                n_state = S_TLP_THIRD_DW;
            end else begin
                n_state = S_IDLE;
            end
            
            $display("%t : S_TLP_SECOND_DW pcie_common::packet_len : %h",$time,pcie_common::packet_len);
          end

          S_TLP_THIRD_DW  : begin
            tlp_third_dw = vif.tx_data_o;
            pcie_common::target_bus_num = tlp_third_dw[31:24];
            pcie_common::target_device_num = tlp_third_dw[23:19];
            pcie_common::target_func_num = tlp_third_dw[18:16];
            pcie_common::ext_reg_num = tlp_third_dw[11:8];
            pcie_common::reg_num = tlp_third_dw[7:2];
//             n_state = S_PROCESS_HEADER;
//             Since we received CFG_RD0, I should send CplD TLP
//           end

//           S_PROCESS_HEADER  : begin
//             If we receive CFG_RD0 from TL => CplD TLP with header space info
//            $display("pcie_common::packet_len : %h",pcie_common::packet_len);

            if (pcie_common::type_t inside {5'b0,5'b1}) begin
              pcie_common::addr = tlp_third_dw;
            end

            case ({pcie_common::fmt,pcie_common::type_t})
              {`CFG_RD0_FMT,`CFG_RD0_TYPE}   : begin
                pcie_common::rcvd_tlp = CfgRd0;
                $display("Inside Cfg_RD0 dll_responder");
                $display("=========== Transmit CplD ============");
                pcie_common::transmit_tlp = CplD;
                pcie_common::rcvd_tlp_count++;
                n_state = S_IDLE_DUMMY;
              end
              
              {`CFG_WR0_FMT,`CFG_WR0_TYPE}   : begin
                $display("Inside Cfg_WR0 dll_responder");
                pcie_common::rcvd_tlp = CfgWr0;
              end

              {`CFG_RD1_FMT,`CFG_RD1_TYPE}   : begin
                $display("Inside Cfg_RD1 dll_responder");
                pcie_common::rcvd_tlp = CfgRd1;
                $display("=========== Transmit CplD ============");
                pcie_common::transmit_tlp = CplD;
                pcie_common::rcvd_tlp_count++;
                n_state = S_IDLE_DUMMY;
              end
              
              {`CFG_WR1_FMT,`CFG_WR1_TYPE}   : begin
                $display("Inside Cfg_WR1 dll_responder");
                pcie_common::rcvd_tlp = CfgWr1;
              end

              {`MEM_WR_FMT,`MEM_WR_TYPE}    : begin
                $display("Inside MEM_WR dll_responder");
                $display("%b",pcie_common::fmt);
                $display("%h %h",pcie_common::addr,pcie_common::ep_bar0_base_addr);
                pcie_common::rcvd_tlp = MWr;
                pcie_common::addr = tlp_third_dw;
              end

              {`MEM_RD_FMT,`MEM_RD_TYPE}    : begin
                $display("Inside MEM_RD dll_responder");
                pcie_common::rcvd_tlp = MRd;
                pcie_common::transmit_tlp = CplD;
                pcie_common::rcvd_tlp_count++;
                n_state = S_IDLE_DUMMY;
              end

            endcase

            if (pcie_common::fmt[1] == 1) begin
              count = 0;
              n_state = S_TLP_PAYLOAD;
            end

            $display("%t : S_TLP_THIRD_DW pcie_common::packet_len : %h",$time,pcie_common::packet_len);
          end

          S_TLP_PAYLOAD : begin
            
            if (count == pcie_common::packet_len) begin
              n_state = S_IDLE_DUMMY;
            end
            
            if (pcie_common::rcvd_tlp == MWr) begin
//               $display("pcie_common::addr : %h",pcie_common::addr);
//               $display("pcie_common::ep_bar0_base_addr : %h",pcie_common::ep_bar0_base_addr);
                dll_cfg_rx::mem[pcie_common::addr - pcie_common::ep_bar0_base_addr + count] = vif.tx_data_o;
//               $display("S_TLP_PAYLOAD MWr %h %h",pcie_common::addr - pcie_common::ep_bar0_base_addr + count , dll_cfg_rx::mem[pcie_common::addr - pcie_common::ep_bar0_base_addr + count]);
            end

            if ( (pcie_common::fmt == `CFG_WR0 && pcie_common::type_t == 5'b00100) ||
                (pcie_common::fmt == `CFG_WR1 && pcie_common::type_t == 5'b00101) ) begin
              pcie_common::ep_bar0_base_addr = payloadQ.pop_front();
              //               $display("ep_bar0_base_addr responder : %h",pcie_common::ep_bar0_base_addr);
            end
            
            count = count + 1;
            payloadQ.push_back(vif.tx_data_o);
            
          end

        endcase

        if (vif.tx_valid_o == 1) begin
          rxdataQ.push_back(vif.tx_data_o);
          vif.tx_ready_i = 1;
        end else begin
          vif.tx_ready_i = 0;
        end
      end
    join
  endtask

endclass

//////////////////////////////////////////////////
class dll_tx_mon extends uvm_monitor;

  virtual tl_dll_intf vif;
  dll_item tx;
  uvm_analysis_port#(dll_item) ap_port;
  `uvm_component_utils(dll_tx_mon)
  `NEW_COMP

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_resource_db#(virtual tl_dll_intf)::read_by_type("DLL", vif, this)) begin
      `uvm_error("RESOURCE_DB_ERROR", "Not able to retrive tl_dll_vif")
    end
    ap_port = new("ap_port",this);
  endfunction

  task run_phase(uvm_phase phase);
    int dw_count;
    bit tlp_collect_f;
    bit [31:0] tlp_header_first_dw;
    bit [31:0] tlp_header_second_dw;
    bit [31:0] tlp_header_third_dw;
    bit [2:0] fmt;
    bit [4:0] type_t;

    wait (vif.mon_cb.arst == 0);
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.tx_valid_o && vif.mon_cb.tx_ready_i) begin
        tlp_collect_f = 1;
        if (dw_count == 1) begin // Ignoring First DW
          tx = new();

          tlp_header_first_dw = vif.mon_cb.tx_data_o;
          fmt = tlp_header_first_dw[31:29];
          type_t = tlp_header_first_dw[28:24];

          case ({fmt,type_t})
              {`CFG_RD0_FMT,`CFG_RD0_TYPE}   : begin
                tx.tlp_type = CfgRd0;
              end
              
              {`CFG_WR0_FMT,`CFG_WR0_TYPE}   : begin
                tx.tlp_type = CfgWr0;
              end

              {`CFG_RD1_FMT,`CFG_RD1_TYPE}   : begin
                tx.tlp_type = CfgRd1;
              end
              
              {`CFG_WR1_FMT,`CFG_WR1_TYPE}   : begin
                tx.tlp_type = CfgWr1;
              end

              {`MEM_WR_FMT,`MEM_WR_TYPE}    : begin
                tx.tlp_type = MWr;
              end

              {`MEM_RD_FMT,`MEM_RD_TYPE}    : begin
                tx.tlp_type = MRd;
              end

            endcase
          tx.headerQ.push_back(vif.mon_cb.tx_data_o);
        end
        if (dw_count == 2) begin
          tlp_header_second_dw = vif.mon_cb.tx_data_o;
          tx.headerQ.push_back(vif.mon_cb.tx_data_o);
        end
        if (dw_count == 3) begin
          tlp_header_third_dw = vif.mon_cb.tx_data_o;
          tx.headerQ.push_back(vif.mon_cb.tx_data_o);
        end

        if (dw_count >= 4) begin
          tx.payloadQ.push_back(vif.mon_cb.tx_data_o);
        end
        dw_count++;
      end else begin
        if (tlp_collect_f == 1) begin
          tlp_collect_f = 0;
          dw_count = 0;
          $display("%t : Collected tlp_data at dll_tx_mon",$time);
          tx.print();
          ap_port.write(tx);
        end
      end
    end
  endtask
endclass


//////////////////////////////////////////////////


class dll_tx_agent extends uvm_test;

  dll_tx_responder responder;
  dll_tx_mon mon;
  // dll_tx_cov cov;

  `uvm_component_utils(dll_tx_agent);
  
  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction //new()

  function void build_phase(uvm_phase phase);
    responder = dll_tx_responder::type_id::create("responder",this);
    // sqr = dll_tx_sqr::type_id::create("sqr",this);
    mon = dll_tx_mon::type_id::create("mon",this);
    // cov = dll_tx_cov::type_id::create("cov",this);
  endfunction

  function void connect_phase(uvm_phase phase);
  endfunction

endclass


//////////////////////////////////////////////////


class dll_rx_drv extends uvm_driver#(dll_item);
  virtual tl_dll_intf vif;
  `uvm_component_utils(dll_rx_drv)
  `NEW_COMP

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_resource_db#(virtual tl_dll_intf)::read_by_type("DLL", vif, this)) begin
      `uvm_error("RESOURCE_DB_ERROR", "Not able to retrive axi_vif")
    end
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      drive_tx(req); //drive the AHB interface with this request
      seq_item_port.item_done();  //I am done with this item
    end
  endtask

  task drive_tx(dll_item tx);
    if (tx.linkup_indicate == 1) begin
      vif.linkup = 1;
    end else if (tx.vc_status_vector == 8'hFF ) begin
      vif.dll_vc_up = 8'hFF;
    end else begin // Drive TLP
      $display("Inside dll_rx_drv");
      foreach (tx.headerQ[i]) begin
        @(posedge vif.tl_dll_clk);
        vif.rx_data_i = tx.headerQ[i];
        vif.rx_valid_i = 1;
//         wait(vif.rx_ready_o);
      end
      if (pcie_common::rcvd_tlp inside {CfgRd0,CfgRd1}) begin
        foreach (tx.payloadQ[i]) begin
          @(posedge vif.tl_dll_clk);
          vif.rx_data_i = tx.payloadQ[i];
          vif.rx_valid_i = 1;
//           wait(vif.rx_ready_o);
        end
      end
      if (pcie_common::rcvd_tlp == MRd) begin
//         $display("Inside MRd If condition");
//         $display("%t : pcie_common::packet_len : %h",$time,pcie_common::packet_len);
//         $display("%t : pcie_common::addr : %h",$time,pcie_common::addr);
        
        
        for (int i=0; i <= pcie_common::packet_len; i++) begin
          @(posedge vif.tl_dll_clk);
//           $display("pcie_common::addr : %h %h",pcie_common::addr - pcie_common::ep_bar0_base_addr,dll_cfg_rx::mem[pcie_common::addr - pcie_common::ep_bar0_base_addr]);
          vif.rx_data_i = dll_cfg_rx::mem[pcie_common::addr - pcie_common::ep_bar0_base_addr];;
          vif.rx_valid_i = 1;
          pcie_common::addr++;
//           wait(vif.rx_ready_o);
        end
      end
        @(posedge vif.tl_dll_clk);
        vif.rx_data_i = 0;
        vif.rx_valid_i = 0;
//       end
    end
  endtask

endclass


//////////////////////////////////////////////////

class dll_rx_mon extends uvm_monitor;

  virtual tl_dll_intf vif;
  dll_item tx;
  uvm_analysis_port#(dll_item) ap_port;
  `uvm_component_utils(dll_rx_mon)
  `NEW_COMP

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_resource_db#(virtual tl_dll_intf)::read_by_type("DLL", vif, this)) begin
      `uvm_error("RESOURCE_DB_ERROR", "Not able to retrive tl_dll_vif")
    end
    ap_port = new("ap_port",this);
  endfunction

  task run_phase(uvm_phase phase);
    int dw_count;
    bit tlp_collect_f;
    bit [31:0] tlp_header_first_dw;
    bit [31:0] tlp_header_second_dw;
    bit [31:0] tlp_header_third_dw;
    bit [2:0] fmt;
    bit [4:0] type_t;

    wait (vif.mon_cb.arst == 0);
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.rx_valid_i && vif.mon_cb.rx_ready_o) begin
        tlp_collect_f = 1;
        if (dw_count == 0) begin
          tx = new();

          tlp_header_first_dw = vif.mon_cb.rx_data_i;
          fmt = tlp_header_first_dw[31:29];
          type_t = tlp_header_first_dw[28:24];

          case ({fmt,type_t})
              {`CFG_RD0_FMT,`CFG_RD0_TYPE}   : begin
                tx.tlp_type = CfgRd0;
              end
              
              {`CFG_WR0_FMT,`CFG_WR0_TYPE}   : begin
                tx.tlp_type = CfgWr0;
              end

              {`CFG_RD1_FMT,`CFG_RD1_TYPE}   : begin
                tx.tlp_type = CfgRd1;
              end
              
              {`CFG_WR1_FMT,`CFG_WR1_TYPE}   : begin
                tx.tlp_type = CfgWr1;
              end

              {`MEM_WR_FMT,`MEM_WR_TYPE}    : begin
                tx.tlp_type = MWr;
              end

              {`MEM_RD_FMT,`MEM_RD_TYPE}    : begin
                tx.tlp_type = MRd;
              end

            endcase
          tx.headerQ.push_back(vif.mon_cb.rx_data_i);
        end
        if (dw_count == 1) begin
          tx.headerQ.push_back(vif.mon_cb.rx_data_i);
          tlp_header_second_dw = vif.mon_cb.rx_data_i;
        end
        if (dw_count == 2) begin
          tx.headerQ.push_back(vif.mon_cb.rx_data_i);
          tlp_header_third_dw = vif.mon_cb.rx_data_i;
        end

        if (dw_count >= 3) begin
          tx.payloadQ.push_back(vif.mon_cb.rx_data_i);
        end else begin
          if (pcie_common::pcie_tl_dll_state == 6'h1b) begin
            tx.mem_data_f = 1;
          end
        end
        dw_count++;
      end else begin
        if (tlp_collect_f == 1) begin
          tlp_collect_f = 0;
          dw_count = 0;
          $display("%t : Collected tlp_data at dll_rx_mon",$time);
          tx.print();
          ap_port.write(tx);
        end
      end
    end
  endtask
endclass


//////////////////////////////////////////////////


typedef uvm_sequencer#(dll_item) dll_rx_sqr;


//////////////////////////////////////////////////

class dll_rx_cov extends uvm_subscriber#(dll_item);
  dll_item tlp;
  `uvm_component_utils(dll_rx_cov);


  covergroup dll_rx_cg;
    CP_FMT :  coverpoint {tlp.headerQ[0][31:29], tlp.headerQ[0][28:24]} {
      bins MEM_RD = {{`MEM_RD_FMT,`MEM_RD_TYPE}};
      bins MEM_WR = {{`MEM_WR_FMT,`MEM_WR_TYPE}};
      bins CFG_RD0 = {{`CFG_RD0_FMT,`CFG_RD0_TYPE}};
      bins CFG_RD1 = {{`CFG_RD1_FMT,`CFG_RD1_TYPE}};
      bins CFG_WR0 = {{`CFG_WR0_FMT,`CFG_WR0_TYPE}};
      bins CFG_WR1 = {{`CFG_WR1_FMT,`CFG_WR1_TYPE}};
      bins CPLD = {{`CPLD_FMT,`CPLD_TYPE}};
    }
  endgroup

  
  function new(string name, uvm_component parent);
    super.new(name,parent);
    dll_rx_cg = new();
  endfunction //new()

  function void write(dll_item t);
    $cast (tlp,t);
    dll_rx_cg.sample();
  endfunction

endclass

//////////////////////////////////////////////////

class dll_rx_agent extends uvm_test;

  dll_rx_drv drv;
  dll_rx_sqr sqr;
  dll_rx_mon mon;
  dll_rx_cov cov;

  `uvm_component_utils(dll_rx_agent);
  
  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction //new()

  function void build_phase(uvm_phase phase);
    drv = dll_rx_drv::type_id::create("drv",this);
    sqr = dll_rx_sqr::type_id::create("sqr",this);
    mon = dll_rx_mon::type_id::create("mon",this);
    cov = dll_rx_cov::type_id::create("cov",this);
  endfunction

  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
    mon.ap_port.connect(cov.analysis_export);

  endfunction

endclass