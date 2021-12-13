`include "defines.v"

module RS (
    input  wire             clk, rst, rdy, 
    input  wire             jp_wrong,                                   // 跳转错误

    // Decoder
    input  wire             ins_flag,                                   // 指令是否有效
    input  wire [`ILEN]     insty,                                      // 指令
    input  wire             rs1_ready, rs2_ready,                       // rs1，rs2 是否拿到真正的值
    input  wire [`RLEN]     reg1, reg2, imm,                            // rs1，rs2，imm 的值，如果 rs1，rs2 没拿到真值，则为 ROB 编号

    // ROB
    input  wire [`RBID]     new_ROB_idx,                                // 新指令在 ROB 中的编号  

    // ALU
    input  wire             val_flag_RS,                                // RS 是否发来更新
    input  wire [`RBID]     val_idx_RS,                                 // RS 更新对应 ROB 编号
    input  wire [`RLEN]     val_RS,                                     // RS 更新的值

    // LSB
    input  wire             val_flag_LSB,                               // LSB 是否发来更新
    input  wire [`RBID]     val_idx_LSB,                                // LSB 更新对应 ROB 编号
    input  wire [`RLEN]     val_LSB,                                     // LSB 更新的值

    // CDB
    output reg              val_flag,                                   // 是否发送给 CDB
    output reg  [`RBID]     val_idx,                                    // ROB 编号
    output reg  [`RLEN]     val                                         // 发送的值

);
    reg  [`ILEN]    ins             [`RSSZ];                            // RS 中保存的指令
    reg  [`RSSZ]    used;                                               // RS 的使用状态
    reg  [`RLEN]    val1            [`RSSZ];                            // RS 存的 rs1 寄存器值
    reg  [`RLEN]    val2            [`RSSZ];                            // RS 存的 rs2 寄存器值
    reg  [`RSSZ]    val1_ready;                                         // RS 中 rs1 是否拿到真值
    reg  [`RSSZ]    val2_ready;                                         // RS 中 rs2 是否拿到真值
    reg  [`RBID]    ROB_idx         [`RSSZ];                            // RS 要把结果发送到的 ROB 编号

    reg             new_rs1_ready, new_rs2_ready;                       // 当前输入指令的 rs1 和 rs2 是否拿到真值
    reg  [`RLEN]    new_reg1, new_reg2;                                 // 当前输入指令的 rs1 和 rs2 的值

    wire [`RSSZ]    idle = (~used) & (-(~used));                        // 最低位未被使用的 RS                                     

    wire [`RSSZ]    ready_state = used & val1_ready & val2_ready;       // RS 中可以运算的所有位置
    wire [`RSSZ]    ready_pos_lowbit = ready_state & (-ready_state);    // RS 中最低位可以运算的位置

    // ALU
    wire             ari_ins_flag;                                      // ALU 是否发来算术指令
    reg  [`ILEN]     ari_insty;                                         // 指令
    reg  [`RLEN]     ari_val1, ari_val2;                                // 需要进行运算的值
    reg  [`RBID]     ari_ROB_idx;                                       // 目标 ROB 编号                
    // output reg              cmp_ins_flag,                            // 是否发给 ALU 比较运算
    // output reg  [`ILEN]     cmp_insty,                               // 发给 ALU 的比较运算指令
    // output reg  [`RLEN]     cmp_val1, cmp_val2,                      // 发给 ALU 的比较运算值
    assign ari_ins_flag = ready_pos_lowbit != 0;

    always @(*) begin
        ari_insty = `null6;
        ari_val1 = `null32;
        ari_val2 = `null32;
        ari_ROB_idx = 0;
        for (i = 0; i < `RSSIZE; i = i + 1)
            if (ready_pos_lowbit[i])
            begin
                ari_insty = ins[i];
                ari_val1 = val1[i];
                ari_val2 = val2[i];
                ari_ROB_idx = ROB_idx[i];
            end

        if (!rs1_ready) begin
            if (val_flag_RS && val_idx_RS == reg1[`RBID]) begin
                new_rs1_ready = `True;
                new_reg1 = val_RS;
            end
            else if (val_flag_LSB && val_idx_LSB == reg1[`RBID])begin
                new_rs1_ready = `True;
                new_reg1 = val_LSB;
            end
            else begin
                new_rs1_ready = rs1_ready;
                new_reg1 = reg1;
            end
        end
        else begin
            new_rs1_ready = rs1_ready;
            new_reg1 = reg1;
        end
        
        if (!rs2_ready) begin
            if (val_flag_RS && val_idx_RS == reg2[`RBID]) begin
                new_rs2_ready = `True;
                new_reg2 = val_RS;
            end
            else if (val_flag_LSB && val_idx_LSB == reg2[`RBID])begin
                new_rs2_ready = `True;
                new_reg2 = val_LSB;
            end
            else begin
                new_rs2_ready = rs2_ready;
                new_reg2 = reg2;
            end
        end
        else begin
            new_rs2_ready = rs2_ready;
            new_reg2 = reg2;
        end
    end
    
    integer i;
    reg [31: 0] debug_now;
    always @(posedge clk) begin
        debug_now <= debug_now + 1;
        // $display("RS: ", debug_now);
        if (rst)
            debug_now <= 0;
        if (rst || jp_wrong) begin
            used <= `null16;
            // val1_ready <= ~(`null16);
            // val2_ready <= ~(`null16);
        end

        if (!rst && rdy && !jp_wrong)
        begin
            if (ins_flag) begin
                for (i = 0; i < `RSSIZE; i = i + 1)
                if (idle[i])
                begin
                    used[i] <= `True;
                    ins[i] <= insty;
                    ROB_idx[i] <= new_ROB_idx;
    
                    val1[i] <= new_reg1;
                    val1_ready[i] <= new_rs1_ready;
    
                    if (insty == `JALR || (!insty[5] && !insty[0] && insty != `SUB)) begin
                        val2[i] <= imm;
                        val2_ready[i] <= `True;    
                    end
                    else begin
                        val2[i] <= new_reg2;
                        val2_ready[i] <= new_rs2_ready;
                    end    
                end
            end

            if (ready_pos_lowbit) begin
                for (i = 0; i < `RSSIZE; i = i + 1)
                    if (ready_pos_lowbit[i])
                        used[i] <= `False;
            end

            for (i = 0; i < `RSSIZE; i = i + 1)
            if (used[i]) begin
                if (val_flag_RS && !val1_ready[i] && val1[i][`RBID] == val_idx_RS) begin
                    val1_ready[i] <= `True;
                    val1[i] <= val_RS;
                end
                if (val_flag_LSB && !val1_ready[i] && val1[i][`RBID] == val_idx_LSB) begin
                    val1_ready[i] <= `True;
                    val1[i] <= val_LSB;
                end

                if (val_flag_RS && !val2_ready[i] && val2[i][`RBID] == val_idx_RS) begin
                    val2_ready[i] <= `True;
                    val2[i] <= val_RS;
                end
                if (val_flag_LSB && !val2_ready[i] && val2[i][`RBID] == val_idx_LSB) begin
                    val2_ready[i] <= `True;
                    val2[i] <= val_LSB;
                end
            end
        end
    end

    // ALU
    always @(*) begin
        if (ari_ins_flag) begin
            val_flag = `True;
            val_idx = ari_ROB_idx;
            case (ari_insty)
                `ADD   : val = ari_val1 + ari_val2;
                `ADDI  : val = ari_val1 + ari_val2;
                `SUB   : val = ari_val1 - ari_val2;
                `XOR   : val = ari_val1 ^ ari_val2;
                `XORI  : val = ari_val1 ^ ari_val2;
                `OR    : val = ari_val1 | ari_val2;
                `ORI   : val = ari_val1 | ari_val2;
                `AND   : val = ari_val1 & ari_val2;
                `ANDI  : val = ari_val1 & ari_val2;
                `SLL   : val = ari_val1 << ari_val2[4:0];
                `SLLI  : val = ari_val1 << ari_val2[4:0];
                `SRL   : val = ari_val1 >> ari_val2[4:0];
                `SRLI  : val = ari_val1 >> ari_val2[4:0];
                `SRA   : val = $signed(ari_val1) >> ari_val2[4:0];
                `SRAI  : val = $signed(ari_val1) >> ari_val2[4:0];
                `SLT   : val = $signed(ari_val1) < $signed(ari_val2);
                `SLTI  : val = $signed(ari_val1) < $signed(ari_val2);
                `SLTU  : val = ari_val1 < ari_val2;
                `SLTIU : val = ari_val1 < ari_val2;
                `BEQ   : val = ari_val1 == ari_val2;
                `BNE   : val = ari_val1 != ari_val2;
                `BLT   : val = $signed(ari_val1) < $signed(ari_val2);
                `BGE   : val = $signed(ari_val1) >= $signed(ari_val2);
                `BLTU  : val = ari_val1 < ari_val2;
                `BGEU  : val = ari_val1 >= ari_val2;
                `JALR  : val = (ari_val1 + ari_val2) & ~(32'b1);
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