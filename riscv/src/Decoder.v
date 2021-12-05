`define True        1'b1
`define False       1'b0
`define null1       1'b0
`define null4       4'b0
`define null5       5'b0
`define null6       6'b0
`define null32      32'b0
`define LB          6'd0
`define LH          6'd1
`define LW          6'd2
`define LBU         6'd3
`define LHU         6'd4
`define SB          6'd5
`define SH          6'd6
`define SW          6'd7
`define LUI         6'd8
`define AUIPC       6'd9
`define ADD         6'd10
`define ADDI        6'd11
`define SUB         6'd12
`define XOR         6'd13
`define XORI        6'd14
`define OR          6'd15
`define ORI         6'd16
`define AND         6'd17
`define ANDI        6'd18
`define SLL         6'd19
`define SLLI        6'd20
`define SRL         6'd21
`define SRLI        6'd22
`define SRA         6'd23
`define SRAI        6'd24
`define SLT         6'd28
`define SLTI        6'd29
`define SLTU        6'd30
`define SLTIU       6'd31
`define BEQ         6'd32
`define BNE         6'd33
`define BLT         6'd34
`define BGE         6'd35
`define BLTU        6'd36
`define BGEU        6'd37
`define JAL         6'd38
`define JALR        6'd39
`define JALOP       7'd111
`define JALROP      7'd103
`define LUIOP       7'd55     
`define RSSIZE      16                                                  // RS 的大小
`define LSBSIZE     16                                                  // LSB 的大小
`define ROBSIZE     16                                                  // ROB 的大小
`define RSSZ        15: 0                                               // RS 的数组大小
`define RSID         3: 0                                               // RS 下标大小
`define RBSZ        15: 0                                               // ROB 的数组大小
`define RBID         3: 0                                               // ROB 的下标大小
`define LSSZ        15: 0                                               // LSB 的数组大小
`define LSID         3: 0                                               // LSB 的下标大小
`define RLEN        31: 0                                               // 寄存器和 pc 的长度
`define RIDX         4: 0                                               // 32 个寄存器的下标
`define ILEN         5: 0                                               // 自定义指令的长度   

module Decoder (
    input  wire             clk, rst, rdy, jp_wrong, 

    // InstFetch
    input  wire             ins_flag, jp_flag, 
    input  wire [31: 0]     ins, jp_pc, 
    output wire             stall_IF, 

    // RegFile
    input  wire             rs1_ready, rs2_ready, 
    input  wire [31: 0]     reg1, reg2, 
    output reg  [ 4: 0]     rs1, rs2, 

    // CDB
    output reg  [ 4: 0]     rd, 
    output reg  [ 5: 0]     insty, 
    output wire             rs1_ready_CDB, rs2_ready_CDB, 
    output wire [31: 0]     reg1_CDB, reg2_CDB, 
    output reg  [31: 0]     imm, 

    // LSB
    output reg              ins_flag_LSB, 
    output wire [ 2: 0]     insty_LSB, 

    // ROB
    input  wire             ROB_full, rs1_ready_ROB, rs2_ready_ROB, 
    input  wire [31: 0]     reg1_ROB, reg2_ROB, 
    output reg              ins_flag_ROB, 
    output reg              jp_flag_ROB, 
    output reg  [31: 0]     jp_pc_ROB, 

    // RS
    output reg              ins_flag_RS
);

    wire [ 6: 0]    opcode = ins[6:0];

    // CDB
    assign rs1_ready_CDB = rs1_ready ? `True : rs1_ready_ROB;
    assign rs2_ready_CDB = rs2_ready ? `True : rs2_ready_ROB;
    assign reg1_CDB = rs1_ready ? reg1 : reg1_ROB;
    assign reg2_CDB = rs2_ready ? reg2 : reg2_ROB;
    assign stall_IF = ROB_full;

    // LSB
    assign insty_LSB = insty[2:0];

    always @(posedge clk) begin
        if (rst || jp_wrong) begin
            ins_flag_ROB <= `null1;
            rd <= `null5;
            rs1 <= `null5;
            rs2 <= `null5;
            insty <= `null6;
            imm <= `null32;
            jp_pc_ROB <= `null32;
            ins_flag_LSB <= `False;
            ins_flag_RS <= `False;
        end
        else if (!rdy || ROB_full) begin
            
        end
        else if (ins_flag) begin
            ins_flag_ROB <= `True;
            ins_flag_LSB <= (opcode == 7'd3 || opcode == 7'd35);

            jp_pc_ROB <= jp_pc;
            rd <= (opcode == 7'd99 || opcode == 7'd35) ? `null5 : ins[11:7];
            rs1 <= (opcode == 7'd111 || opcode == 7'd55 || opcode == 7'd23) ? `null5 : ins[19:15];
            rs2 <= (opcode == 7'd99 || opcode == 7'd35 || opcode == 7'd51) ? ins[24:20] : `null5;
            case (opcode)
                7'd3 : begin
                    case (ins[14:12])
                        3'b001: insty <= `LH;
                        3'b010: insty <= `LW;
                        3'b100: insty <= `LBU;
                        3'b101: insty <= `LHU; 
                        3'b000: insty <= `LB;
                    endcase
                    imm <= {{20{ins[31]}}, ins[31:20]};

                    ins_flag_RS <= `False;
                end
                7'd35 : begin
                    case (ins[14:12])
                        3'b000: insty <= `SB;
                        3'b001: insty <= `SH;
                        3'b010: insty <= `SW;
                    endcase
                    imm <= {{20{ins[31]}}, ins[31:25], ins[11:7]};

                    ins_flag_RS <= `False;
                end
                7'd19 : begin
                    case (ins[14:12])
                        3'b000: insty <= `ADDI; 
                        3'b100: insty <= `XORI;
                        3'b110: insty <= `ORI;
                        3'b111: insty <= `ANDI;
                        3'b001: insty <= `SLLI;
                        3'b101: insty <= (ins[30] ? `SRAI : `SRLI);
                        3'b010: insty <= `SLTI;
                        3'b011: insty <= `SLTIU;
                    endcase
                    imm <= (ins[14:12] == 1 || ins[14:12] == 5) ? {{20{ins[31]}}, ins[31:20]} : {27'b0, ins[24:20]};

                    ins_flag_RS <= `True;
                end
                7'd51 : begin
                    case (ins[14:12])
                        3'b000: insty <= (ins[30] ? `SUB : `ADD);
                        3'b100: insty <= `XOR;
                        3'b110: insty <= `OR;
                        3'b111: insty <= `AND;
                        3'b001: insty <= `SLL;
                        3'b101: insty <= (ins[30] ? `SRA : `SRL);
                        3'b010: insty <= `SLT;
                        3'b011: insty <= `SLTU;
                    endcase

                    ins_flag_RS <= `True;
                end
                7'd99 : begin
                    case (ins[14:12])
                        3'b000: insty <= `BEQ;
                        3'b001: insty <= `BNE;
                        3'b100: insty <= `BLT;
                        3'b101: insty <= `BGE;
                        3'b110: insty <= `BLTU;
                        3'b111: insty <= `BGEU;
                    endcase
                    imm <= {{20{ins[31]}}, ins[7], ins[31:25], ins[11:8]} << 1; 

                    ins_flag_RS <= `True;
                end
                7'd55 : begin
                    imm <= ins[31:12] << 12;
                    insty <= `LUI;

                    ins_flag_RS <= `False;
                end
                7'd23 : begin
                    imm <= ins[31:12] << 12;
                    insty <= `AUIPC;

                    ins_flag_RS <= `False;
                end
                7'd111 : begin
                    imm <= {{12{ins[31]}}, ins[19:12], ins[20], ins[30:21]} << 1;
                    insty <= `JAL;

                    ins_flag_RS <= `False;
                end
                7'd103 : begin
                    imm <= {{20{ins[31]}}, ins[31:20]};
                    insty <= `JALR;

                    ins_flag_RS <= `True;
                end
            endcase
        end
        else begin
            ins_flag_ROB <= `null1;
        end
    end
    
endmodule