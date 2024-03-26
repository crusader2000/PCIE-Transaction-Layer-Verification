int value;

`define NEW_COMP \
function new(string name, uvm_component parent); \
  super.new(name,parent); \
endfunction //new()

`define NEW_OBJ \
function new(string name=""); \
  super.new(name); \
endfunction //new()

typedef enum bit [1:0] {
	FIXED,
    INCR,
  	WRAP,
  RSVD_BT
} burst_type_t;


`define CFG_RD0 3'b000
`define CFG_RD1 3'b001
`define CFG_WR0 3'b010
`define CFG_WR1 3'b011

`define MEM_WR 5'b0_0001
`define MEM_RD 5'b0_0010
`define IO_WR 5'b0_011
`define IO_RD 5'b0_100
`define CFG_WR 5'b0_101
`define CFG_RD 5'b0_110
`define MSG 5'b0_111

`define CFG_RD0_FMT 3'b000
`define CFG_RD1_FMT 3'b000
`define CFG_WR0_FMT 3'b010
`define CFG_WR1_FMT 3'b010
`define MEM_WR_FMT 3'b010
`define MEM_RD_FMT 3'b000
`define IO_WR_FMT 3'b010
`define IO_RD_FMT 3'b000
`define MSG_FMT 3'b001
`define CPLD_FMT 3'b010

`define CFG_RD0_TYPE 5'b00100
`define CFG_RD1_TYPE 5'b00101
`define CFG_WR0_TYPE 5'b00100
`define CFG_WR1_TYPE 5'b00101
`define MEM_WR_TYPE 5'b00000
`define MEM_RD_TYPE 5'b00000
`define IO_WR_TYPE 5'b00010
`define IO_RD_TYPE 5'b00010
`define MSG_TYPE 5'b10000
`define CPLD_TYPE 5'b01010

`define ENDPOINT 32'h0
`define SWITCH 32'h1

`define PAYLOAD_SIZE 256

`define MST 1'b1
`define SLV 1'b0

typedef enum bit [1:0] {
  NORMAL,
  EXCL,
  LOCKED,
  RSVD_LK
} lock_t;

typedef enum bit [4:0] {
  NONE_TLP,
  MRd,
  MWr,
  IORd,
  IOWr,
  CfgRd0,
  CfgRd1,
  CfgWr0,
  CfgWr1,
  Msg,
  MsgD,
  Cpl,
  CplD
} tlp_type_t;

class pcie_common;
  static bit [4:0] pcie_tl_dll_state;
  
  static int rcvd_tlp_count;
  static bit [3:0] state;

  static bit [2:0] fmt;
  static bit [4:0] type_t;
  static bit [9:0] tag ;
  static bit [2:0] tc ;
  static bit [2:0] attr;
  static bit  ln;
  static bit  th;
  static bit  td;
  static bit  ep;
  static bit [1:0] at;
  static bit [9:0] packet_len;
  static bit [15:0] requester_id;
  static bit [3:0] last_dw_be;
  static bit [3:0] first_dw_be;
  static bit [7:0] target_bus_num;
  static bit [4:0] target_device_num;
  static bit [2:0] target_func_num;
  static bit [3:0] ext_reg_num;
  static bit [5:0] reg_num;
  static bit [7:0] requester_bus_num;
  static bit [4:0] requester_device_num;
  static bit [2:0] requester_func_num;
  static tlp_type_t rcvd_tlp;
  static tlp_type_t transmit_tlp;
  static bit [31:0] ep_bar0_base_addr;
  static bit [31:0] addr;

  static int num_tx_matches;
  static int num_tx_mismatches;
  static int num_rx_matches;
  static int num_rx_mismatches;
  static int num_tx_rx_matches;
  static int num_tx_rx_mismatches;

endclass

//////////////////////////////////////////////////

class dll_cfg_rx;
  static bit [15:0] vendor_id;
  static bit [15:0] device_id;
  static bit [15:0] command;
  static bit [15:0] status;
  static bit [7:0] revision_id;
  static bit [23:0] class_code;
  static bit [7:0] latency_time;
  static bit [7:0] cache_line_size;
  static bit [7:0] header_type;
  static bit [7:0] bist;
  static bit [31:0] bar0;
  static bit [31:0] bar1;
  static bit [31:0] bar2;
  static bit [31:0] bar3;
  static bit [31:0] bar4;
  static bit [31:0] bar5;
  static bit [31:0] cardbus_cis_pointer;
  static bit [15:0] subsystem_vendor_id;
  static bit [15:0] subsystem_id;
  static bit [31:0] expansion_rom_base_addr;
  static bit [7:0] capability_pointer;
  static bit [7:0] interrupt_line;
  static bit [7:0] interrupt_pin;
  static bit [7:0] min_gnt;
  static bit [7:0] max_lat;
  static bit [31:0] mem [1024:0];


  static function void vip_cfg_as_ep();
    vendor_id = 16'h4569;
    device_id = 16'h2153;
    command = 16'h1234;
    status = 16'hAABB;
    revision_id = 8'hAB;
    class_code = 24'h123456;
    latency_time = 8'hFF;
    cache_line_size = 8'hEE;
    header_type = 8'h01;
    bist = 8'hCC;
    bar0 = 32'hFFFF_0004; // 2**16 = 64 KB memory size
    bar1 = 32'hFFFF_FFFF;
    bar2 = 32'hFFFF_FFFF;
    bar3 = 32'hFFFF_FFFF;
    bar4 = 32'hFFFF_FFFF;
    bar5 = 32'hFFFF_FFFF;
    cardbus_cis_pointer = 32'h1234_5678;
    subsystem_vendor_id = 16'hCCDD;
    subsystem_id = 16'hEEFF;
    expansion_rom_base_addr = 32'h11223344;
    capability_pointer = 8'h56;
    interrupt_line = 8'hAB;
    interrupt_pin = 8'hCD;
    min_gnt = 8'h12;
    max_lat = 8'hAB;
  endfunction

  static function void vip_cfg_as_rc();
  endfunction

  static function void vip_cfg_as_switch();
  endfunction

endclass

//////////////////////////////////////////////////
