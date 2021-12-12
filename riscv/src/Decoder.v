`include "defines.v"

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
    input  wire             ROB_full, LSB_full, 
    input  wire             rs1_ready_ROB, rs2_ready_ROB, 
    input  wire [31: 0]     reg1_ROB, reg2_ROB, 
    output reg              ins_flag_ROB, 
    output reg              jp_flag_ROB, 
    output reg  [31: 0]     jp_pc_ROB, 
    output reg  [31: 0]     debug_ins_ROB, 

    // RS
    output reg              ins_flag_RS
);

    // CDB
    assign rs1_ready_CDB = rs1_ready ? `True : rs1_ready_ROB;
    assign rs2_ready_CDB = rs2_ready ? `True : rs2_ready_ROB;
    assign reg1_CDB = rs1_ready ? reg1 : reg1_ROB;
    assign reg2_CDB = rs2_ready ? reg2 : reg2_ROB;
    assign stall_IF = ROB_full | LSB_full;

    // LSB
    assign insty_LSB = insty[2:0];

    reg  [31: 0]    debug_now;
    reg  [31: 0]    now_ins;
    wire [ 6: 0]    opcode = now_ins[6:0];
    always @(*) begin
        if (ins_flag_ROB) begin
            ins_flag_LSB = (opcode == 7'd3 || opcode == 7'd35);

            rd = (opcode == 7'd99 || opcode == 7'd35) ? `null5 : now_ins[11:7];
            rs1 = (opcode == 7'd111 || opcode == 7'd55 || opcode == 7'd23) ? `null5 : now_ins[19:15];
            rs2 = (opcode == 7'd99 || opcode == 7'd35 || opcode == 7'd51) ? now_ins[24:20] : `null5;
            case (opcode)
                7'd3 : begin
                    case (now_ins[14:12])
                        3'b001: insty = `LH;
                        3'b010: insty = `LW;
                        3'b100: insty = `LBU;
                        3'b101: insty = `LHU; 
                        3'b000: insty = `LB;
                        default: insty = `null6;
                    endcase
                    imm = {{20{now_ins[31]}}, now_ins[31:20]};

                    ins_flag_RS = `False;
                end
                7'd35 : begin
                    case (now_ins[14:12])
                        3'b000: insty = `SB;
                        3'b001: insty = `SH;
                        3'b010: insty = `SW;
                        default: insty = `null6;
                    endcase
                    imm = {{20{now_ins[31]}}, now_ins[31:25], now_ins[11:7]};

                    ins_flag_RS = `False;
                end
                7'd19 : begin
                    case (now_ins[14:12])
                        3'b000: insty = `ADDI; 
                        3'b100: insty = `XORI;
                        3'b110: insty = `ORI;
                        3'b111: insty = `ANDI;
                        3'b001: insty = `SLLI;
                        3'b101: insty = (now_ins[30] ? `SRAI : `SRLI);
                        3'b010: insty = `SLTI;
                        3'b011: insty = `SLTIU;
                        default: insty = `null6;
                    endcase
                    imm = (now_ins[14:12] == 1 || now_ins[14:12] == 5) ? {27'b0, now_ins[24:20]} : {{20{now_ins[31]}}, now_ins[31:20]};

                    ins_flag_RS = `True;
                end
                7'd51 : begin
                    case (now_ins[14:12])
                        3'b000: insty = (now_ins[30] ? `SUB : `ADD);
                        3'b100: insty = `XOR;
                        3'b110: insty = `OR;
                        3'b111: insty = `AND;
                        3'b001: insty = `SLL;
                        3'b101: insty = (now_ins[30] ? `SRA : `SRL);
                        3'b010: insty = `SLT;
                        3'b011: insty = `SLTU;
                        default: insty = `null6;
                    endcase
                    imm = `null32;

                    ins_flag_RS = `True;
                end
                7'd99 : begin
                    case (now_ins[14:12])
                        3'b000: insty = `BEQ;
                        3'b001: insty = `BNE;
                        3'b100: insty = `BLT;
                        3'b101: insty = `BGE;
                        3'b110: insty = `BLTU;
                        3'b111: insty = `BGEU;
                        default: insty = `null6;
                    endcase
                    imm = {{20{now_ins[31]}}, now_ins[7], now_ins[31:25], now_ins[11:8]} << 1; 

                    ins_flag_RS = `True;
                end
                7'd55 : begin
                    imm = now_ins[31:12] << 12;
                    insty = `LUI;

                    ins_flag_RS = `False;
                end
                7'd23 : begin
                    imm = now_ins[31:12] << 12;
                    insty = `AUIPC;

                    ins_flag_RS = `False;
                end
                7'd111 : begin
                    imm = {{12{now_ins[31]}}, now_ins[19:12], now_ins[20], now_ins[30:21]} << 1;
                    insty = `JAL;

                    ins_flag_RS = `False;
                end
                7'd103 : begin
                    imm = {{20{now_ins[31]}}, now_ins[31:20]};
                    insty = `JALR;

                    ins_flag_RS = `True;
                end
                default: begin
                    imm = `null32;
                    insty = `null6;
                    ins_flag_RS = `False;
                end
            endcase
        end
        else begin
            ins_flag_LSB = `False;
            ins_flag_RS = `False;
            rd = `null5;
            rs1 = `null5;
            rs2 = `null5;
            insty = `null6;
            imm = `null32;
        end
    end

    always @(posedge clk) begin
        debug_now <= debug_now + 1;
        // $display("DC: ", debug_now);

        if (rst)
            debug_now <= 0;
        if (rst || jp_wrong || !ins_flag || ROB_full || LSB_full) begin
            ins_flag_ROB <= `False;
            now_ins <= `null32;
            jp_flag_ROB <= `False;
            jp_pc_ROB <= `null32;
        end
        else if (!rdy) begin
            
        end
        else begin
            debug_ins_ROB <= ins;
            ins_flag_ROB <= `True;
            jp_flag_ROB <= jp_flag;
            jp_pc_ROB <= jp_pc;
            now_ins <= ins;
        end
    end
    
endmodule