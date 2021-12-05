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

module ALU (
    input  wire             clk, rst, rdy, 
    input  wire             jp_wrong,                                   // 跳转错误

    // CDB
    output reg              val_flag,                                   // 是否发送给 CDB
    output reg  [`RBID]     val_idx,                                    // ROB 编号
    output reg  [`RLEN]     val,                                        // 发送的值

    // RS
    input  wire             ins_flag,                                   // ALU 是否发来算术指令
    input  wire [`ILEN]     insty,                                      // 指令
    input  wire [`RLEN]     val1, val2,                                 // 需要进行运算的值
    input  wire [`RBID]     ROB_idx                                     // 目标 ROB 编号
                                 
);

    always @(*) begin
        if (ins_flag) begin
            val_flag = `True;
            val_idx = ROB_idx;
            case (insty)
                `ADD   : val = val1 + val2;
                `ADDI  : val = val1 + val2;
                `SUB   : val = val1 - val2;
                `XOR   : val = val1 ^ val2;
                `XORI  : val = val1 ^ val2;
                `OR    : val = val1 | val2;
                `ORI   : val = val1 | val2;
                `AND   : val = val1 & val2;
                `ANDI  : val = val1 & val2;
                `SLL   : val = val1 << val2[4:0];
                `SLLI  : val = val1 << val2[4:0];
                `SRL   : val = val1 >> val2[4:0];
                `SRLI  : val = val1 >> val2[4:0];
                `SRA   : val = $signed(val1) >> val2[4:0];
                `SRAI  : val = $signed(val1) >> val2[4:0];
                `SLT   : val = $signed(val1) < $signed(val2);
                `SLTI  : val = $signed(val1) < $signed(val2);
                `SLTU  : val = val1 < val2;
                `SLTIU : val = val1 < val2;
                `BEQ   : val = val1 == val2;
                `BNE   : val = val1 != val2;
                `BLT   : val = $signed(val1) < $signed(val2);
                `BGE   : val = $signed(val1) >= $signed(val2);
                `BLTU  : val = val1 < val2;
                `BGEU  : val = val1 >= val2;
                `JALR  : val = (val1 + val2) & ~(32'b1);
                default: val = `null32;
            endcase
        end
        else begin
            val_flag = `False;
            val_idx = `null4;
            val = `null32;
        end
    end
    
endmodule