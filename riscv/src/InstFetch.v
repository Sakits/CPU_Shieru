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

module InstFetch (
    input  wire             clk, rst, rdy, 

    // ROB
    input  wire             jp_wrong,
    input  wire [31: 0]     jp_pc, 
    
    // Decoder
    input  wire             stall_ID, 
    output reg              ins_flag_ID, jp_flag_ID, 
    output reg  [31: 0]     ins_ID, jp_pc_ID,  
    
    // ICache
    input  wire             ins_flag, 
    input  wire [31: 0]     ins, 
    output reg  [31: 0]     pc
);
    reg  [31: 0]    imm;

    always @(*) begin
        if (ins[6]) begin
            if (ins[2]) 
                imm = {{12{ins[31]}}, ins[19:12], ins[20], ins[30:21]} << 1;
            else
                imm = {{20{ins[31]}}, ins[7], ins[31:25], ins[11:8]} << 1;
        end
        else
            imm <= ins[31:12] << 12;     
    end

    wire [ 6: 0]    opcode = ins[6:0];

    always @(posedge clk) begin
        if (rst) begin
            ins_flag_ID <= `null1;
            jp_flag_ID <= `null1;
            ins_ID <= `null32;
            jp_pc_ID <= `null32;
            pc <= `null32;
        end 
        else if (!rdy) begin
            
        end
        else if (jp_wrong) begin
            pc <= jp_pc;
            jp_flag_ID <= `null1;
            ins_flag_ID <= `null1;
            ins_ID <= `null32;
            jp_pc_ID <= `null32;
        end
        else if (stall_ID) begin
            
        end
        else if (ins_flag) begin
            pc <= (opcode == `JALOP) ? pc + imm : pc + 4;
            jp_flag_ID <= 4 == imm;
            if (opcode == `JALOP || opcode == `JALROP)
                jp_pc_ID <= pc + 4;
            else if (opcode == `LUIOP)
                jp_pc_ID <= pc;
            else 
                jp_pc_ID <= pc + imm;
            ins_flag_ID <= `True;
            ins_ID <= ins;
        end
        else begin
            ins_flag_ID <= `null1;
        end
    end

endmodule