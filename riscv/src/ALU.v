`include "defines.v"

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