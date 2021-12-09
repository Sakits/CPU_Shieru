`include "defines.v"

// RISCV32I CPU top module
// port modification allowed for debugging purposes

module cpu(
    input  wire                 clk_in,			// system clock signal
    input  wire                 rst_in,			// reset signal
	input  wire				    rdy_in,			// ready signal, pause cpu when low

    input  wire [ 7:0]          mem_din,		// data input bus
    output wire [ 7:0]          mem_dout,		// data output bus
    output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
    output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

assign mem_dout = MC_mem_dout;
assign mem_a = MC_mem_a;
assign mem_wr = MC_mem_wr;

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)


wire                IF_ins_flag_ID, IF_jp_flag_ID;
wire [31: 0]        IF_ins_ID, IF_jp_pc_ID;

wire [31: 0]        IF_pc_out;
wire                IF_is_stall_IC;

IF IF(
    // input
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in), .jp_wrong(ROB_jp_wrong), .jp_pc(ROB_jp_pc_IF), 

    // Decoder
    // input
    .stall_ID(DC_stall_IF), 
    // output
    .ins_flag_ID(IF_ins_flag_ID), .jp_flag_ID(IF_jp_flag_ID), 
    .ins_ID(IF_ins_ID), .jp_pc_ID(IF_jp_pc_ID), 

    // ICache
    // input
    .ins_flag(IC_ins_flag_IF), .ins(IC_ins_IF), 
    // output
    .pc_out(IF_pc_out), 
    .is_stall_IC(IF_is_stall_IC)
);

wire                IC_ins_flag_IF;
wire [31: 0]        IC_ins_IF;

wire                IC_ins_flag_MC;
wire [31: 0]        IC_pc_MC;

ICache ICache(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in), .jp_wrong(ROB_jp_wrong),

    // IF
    // input
    .pc(IF_pc_out), 
    .is_stall(IF_is_stall_IC), 
    // output
    .ins_flag_IF(IC_ins_flag_IF), 
    .ins_IF(IC_ins_IF), 

    // MemCtrl
    // input
    .ins_flag(MC_val_out_flag_IC), .ins(MC_val_out_IC), 
    // output
    .ins_flag_MC(IC_ins_flag_MC), 
    .pc_MC(IC_pc_MC)
);

wire                DC_stall_IF;

wire [ 4: 0]        DC_rs1, DC_rs2;

wire [ 4: 0]        DC_rd; 
wire [ 5: 0]        DC_insty;
wire                DC_rs1_ready_CDB, DC_rs2_ready_CDB;
wire [31: 0]        DC_reg1_CDB, DC_reg2_CDB;
wire [31: 0]        DC_imm;

wire                DC_ins_flag_LSB;
wire [ 2: 0]        DC_insty_LSB;

wire                DC_ins_flag_ROB;
wire                DC_jp_flag_ROB;
wire [31: 0]        DC_jp_pc_ROB;

wire DC_ins_flag_RS;

Decoder Decoder(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in), .jp_wrong(ROB_jp_wrong),
    
    // IF
    // input 
    .ins_flag(IF_ins_flag_ID), .jp_flag(IF_jp_flag_ID), 
    .ins(IF_ins_ID), .jp_pc(IF_jp_pc_ID), 
    // output
    .stall_IF(DC_stall_IF), 

    // RegFile
    // input
    .rs1_ready(RF_reg1_flag_ID), .rs2_ready(RF_reg2_flag_ID), 
    .reg1(RF_reg1_ID), .reg2(RF_reg2_ID), 
    // output
    .rs1(DC_rs1), .rs2(DC_rs2), 

    // CDB
    // output
    .rd(DC_rd), .insty(DC_insty), 
    .rs1_ready_CDB(DC_rs1_ready_CDB), .rs2_ready_CDB(DC_rs2_ready_CDB), 
    .reg1_CDB(DC_reg1_CDB), .reg2_CDB(DC_reg2_CDB), 
    .imm(DC_imm), 

    // LSB
    // output
    .ins_flag_LSB(DC_ins_flag_LSB), 
    .insty_LSB(DC_insty_LSB), 

    // ROB
    // input
    .ROB_full(ROB_ROB_full), 
    .rs1_ready_ROB(ROB_rs1_ready_ID), .rs2_ready_ROB(ROB_rs2_ready_ID), 
    .reg1_ROB(ROB_reg1_ID), .reg2_ROB(ROB_reg2_ID), 
    // output
    .ins_flag_ROB(DC_ins_flag_ROB), 
    .jp_flag_ROB(DC_jp_flag_ROB), 
    .jp_pc_ROB(DC_jp_pc_ROB), 

    // RS
    // output
    .ins_flag_RS(DC_ins_flag_RS)
);

wire                ROB_jp_wrong;

wire [`RLEN]        ROB_jp_pc_IF;

wire [`RBID]        ROB_front, ROB_rear;

wire                ROB_ROB_full, ROB_rs1_ready_ID, ROB_rs2_ready_ID;
wire [`RLEN]        ROB_reg1_ID, ROB_reg2_ID;

wire                ROB_upd_flag;
wire [`RBID]        ROB_upd_idx;
wire [`RIDX]        ROB_upd_rd;
wire                ROB_write_flag;
wire [`RBID]        ROB_write_idx;
wire [`RIDX]        ROB_write_rd;
wire [`RLEN]        ROB_new_val;

wire                ROB_store_flag;

ROB ROB(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in), .jp_wrong(ROB_jp_wrong),

    // IF
    // output
    .jp_pc_IF(ROB_jp_pc_IF),

    // CDB
    // output
    .front(ROB_front), .rear(ROB_rear),

    // Decoder
    // input
    .jp_flag(DC_jp_flag_ROB), .ins_flag(DC_ins_flag_ROB),
    .rd(DC_rd), .insty(DC_insty), .jp_pc(DC_jp_pc_ROB),
    // output
    .ROB_full(ROB_ROB_full), 
    .rs1_ready_ID(ROB_rs1_ready_ID), .rs2_ready_ID(ROB_rs2_ready_ID),
    .reg1_ID(ROB_reg1_ID), .reg2_ID(ROB_reg2_ID),

    // RegFile 
    // input
    .rs1_idx(RF_rs1_pos), .rs2_idx(RF_rs2_pos),
    // output
    .upd_flag(ROB_upd_flag), 
    .upd_idx(ROB_upd_idx), 
    .upd_rd(ROB_upd_rd), 
    .write_flag(ROB_write_flag), 
    .write_idx(ROB_write_idx), 
    .write_rd(ROB_write_rd), 
    .new_val(ROB_new_val),

    // ALU
    // input
    .val_flag_RS(ALU_val_flag), .val_idx_RS(ALU_val_idx), .val_RS(ALU_val),

    // LSB
    // input
    .val_flag_LSB(LSB_val_flag_LSB), .val_idx_LSB(LSB_val_idx_LSB), .val_LSB(LSB_val_LSB),
    // output
    .store_flag(ROB_store_flag)
);

wire                RF_reg1_flag_ID, RF_reg2_flag_ID;
wire [31: 0]        RF_reg1_ID, RF_reg2_ID;

wire [ 3: 0]        RF_rs1_pos, RF_rs2_pos;
RegFile RegFile(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in), .jp_wrong(ROB_jp_wrong),

    // Decoder
    // input
    .rs1(DC_rs1), .rs2(DC_rs2), 
    // output
    .reg1_flag_ID(RF_reg1_flag_ID), .reg2_flag_ID(RF_reg2_flag_ID), 
    .reg1_ID(RF_reg1_ID), .reg2_ID(RF_reg2_ID), 

    // ROB
    // input
    .upd(ROB_upd_flag), .write(ROB_write_flag), 
    .upd_idx(ROB_upd_idx), .write_idx(ROB_write_idx), 
    .upd_rd(ROB_upd_rd), .write_rd(ROB_write_rd), 
    .new_val(ROB_new_val), 
    // output
    .rs1_pos(RF_rs1_pos), .rs2_pos(RF_rs2_pos)
);

wire                RS_ari_ins_flag; 
wire [`ILEN]        RS_ari_insty;
wire [`RLEN]        RS_ari_val1, RS_ari_val2;
wire [`RBID]        RS_ari_ROB_idx;
RS RS(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in), .jp_wrong(ROB_jp_wrong),

    // Decoder
    // input
    .ins_flag(DC_ins_flag_RS), 
    .insty(DC_insty), 
    .rs1_ready(DC_rs1_ready_CDB), .rs2_ready(DC_rs2_ready_CDB), 
    .reg1(DC_reg1_CDB), .reg2(DC_reg2_CDB), .imm(DC_imm), 

    // ROB
    // input
    .new_ROB_idx(ROB_rear), 

    // ALU
    // input
    .val_flag_RS(ALU_val_flag), 
    .val_idx_RS(ALU_val_idx), 
    .val_RS(ALU_val), 
    // output
    .ari_ins_flag(RS_ari_ins_flag), 
    .ari_insty(RS_ari_insty), 
    .ari_val1(RS_ari_val1), .ari_val2(RS_ari_val2), 
    .ari_ROB_idx(RS_ari_ROB_idx), 
    // output reg              cmp_ins_flag,                            // 是否发给 ALU 比较运算
    // output reg  [`ILEN]     cmp_insty,                               // 发给 ALU 的比较运算指令
    // output reg  [`RLEN]     cmp_val1, cmp_val2,                      // 发给 ALU 的比较运算值

    // LSB
    // input
    .val_flag_LSB(LSB_val_flag_LSB), 
    .val_idx_LSB(LSB_val_idx_LSB), 
    .val_LSB(LSB_val_LSB) 
);

wire                ALU_val_flag;
wire [`RBID]        ALU_val_idx;
wire [`RLEN]        ALU_val; 
ALU ALU(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in), .jp_wrong(ROB_jp_wrong),

    // CDB
    // output
    .val_flag(ALU_val_flag), 
    .val_idx(ALU_val_idx), 
    .val(ALU_val), 

    // RS
    // input
    .ins_flag(RS_ari_ins_flag), .insty(RS_ari_insty), 
    .val1(RS_ari_val1), .val2(RS_ari_val2), 
    .ROB_idx(RS_ari_ROB_idx)
);

wire                LSB_val_flag_LSB; 
wire [`RBID]        LSB_val_idx_LSB; 
wire [`RLEN]        LSB_val_LSB;

wire                LSB_val_flag_MC;
wire [ 2: 0]        LSB_insty_MC;
wire [31: 0]        LSB_addr_out;
wire [31: 0]        LSB_val_out;
LSB LSB(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in), .jp_wrong(ROB_jp_wrong),

    // CDB
    // output
    .val_flag_LSB(LSB_val_flag_LSB), 
    .val_idx_LSB(LSB_val_idx_LSB), 
    .val_LSB(LSB_val_LSB), 

    // Decoder
    // input
    .ins_flag(DC_ins_flag_LSB), .insty(DC_insty_LSB), 
    .rs1_ready(DC_rs1_ready_CDB), .rs2_ready(DC_rs2_ready_CDB), 
    .reg1(DC_reg1_CDB), .reg2(DC_reg2_CDB), .imm(DC_imm), 

    // ROB
    // input
    .new_ROB_idx(ROB_rear),
    .ROB_front(ROB_front), 
    .store_flag(ROB_store_flag), 

    // RS
    // input
    .val_flag_RS(ALU_val_flag), 
    .val_idx_RS(ALU_val_idx), 
    .val_RS(ALU_val), 

    // MemCtrl
    // input
    .val_flag(MC_val_out_flag_LSB), .val_in(MC_val_out_LSB), 
    // output
    .val_flag_MC(LSB_val_flag_MC), 
    .insty_MC(LSB_insty_MC), 
    .addr_out(LSB_addr_out), 
    .val_out(LSB_val_out)
);

wire                MC_val_out_flag_IC;
wire [31: 0]        MC_val_out_IC; 

wire                MC_val_out_flag_LSB;
wire [31: 0]        MC_val_out_LSB;

wire [ 7: 0]        MC_mem_dout;
wire [31: 0]        MC_mem_a;
wire                MC_mem_wr;
MemCtrl MemCtrl(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in), .jp_wrong(ROB_jp_wrong),

    // ICache
    // input
    .val_in_flag_IC(IC_ins_flag_MC), 
    .addr_IC(IC_pc_MC), 
    // output
    .val_out_flag_IC(MC_val_out_flag_IC), 
    .val_out_IC(MC_val_out_IC), 

    // LSB
    // input
    .val_in_flag_LSB(LSB_val_flag_MC),
    .val_in_LSB(LSB_val_out), 
    .insty_LSB(LSB_insty_MC), 
    .addr_LSB(LSB_addr_out), 
    // output
    .val_out_flag_LSB(MC_val_out_flag_LSB), 
    .val_out_LSB(MC_val_out_LSB), 

    // RAM
    // input
    .io_buffer_full(io_buffer_full), 
    .mem_din(mem_din), 
    // output
    .mem_dout(MC_mem_dout), 
    .mem_a(MC_mem_a), 
    .mem_wr(MC_mem_wr)
);

endmodule