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
    input  wire             ari_val_flag_RS,                                // RS 是否发来更新
    input  wire [`RBID]     ari_val_idx_RS,                                 // RS 更新对应 ROB 编号
    input  wire [`RLEN]     ari_val_RS,                                     // RS 更新的值

    // LSB
    input  wire             val_flag_LSB,                               // LSB 是否发来更新
    input  wire [`RBID]     val_idx_LSB,                                // LSB 更新对应 ROB 编号
    input  wire [`RLEN]     val_LSB,                                    // LSB 更新的值

    // CDB
    output reg              ari_val_flag,                               // 是否发送给 CDB
    output reg  [`RBID]     ari_val_idx,                                // ROB 编号
    output reg  [`RLEN]     ari_val,                                    // 发送的值
    output reg              cmp_val_flag,                               // 是否发送给 CDB
    output reg  [`RBID]     cmp_val_idx,                                // ROB 编号
    output reg  [`RLEN]     cmp_val                                     // 发送的值

);
    reg  [`ILEN]    ins             [`RSSZ];                            // RS 中保存的指令
    reg  [`RSSZ]    used, ari_used, cmp_used;                           // RS 的使用状态
    reg  [`RLEN]    val1            [`RSSZ];                            // RS 存的 rs1 寄存器值
    reg  [`RLEN]    val2            [`RSSZ];                            // RS 存的 rs2 寄存器值
    reg  [`RSSZ]    val1_ready;                                         // RS 中 rs1 是否拿到真值
    reg  [`RSSZ]    val2_ready;                                         // RS 中 rs2 是否拿到真值
    reg  [`RBID]    ROB_idx         [`RSSZ];                            // RS 要把结果发送到的 ROB 编号

    reg             new_rs1_ready, new_rs2_ready;                       // 当前输入指令的 rs1 和 rs2 是否拿到真值
    reg  [`RLEN]    new_reg1, new_reg2;                                 // 当前输入指令的 rs1 和 rs2 的值

    wire [`RSSZ]    idle = (~used) & (-(~used));                        // 最低位未被使用的 RS                                     

    wire [`RSSZ]    ari_ready = ari_used & val1_ready & val2_ready;
    wire [`RSSZ]    ari_ready_pos = ari_ready & (-ari_ready);
    wire [`RSSZ]    cmp_ready = cmp_used & val1_ready & val2_ready;
    wire [`RSSZ]    cmp_ready_pos = cmp_ready & (-cmp_ready);

    // ALU
    wire             ari_ins_flag;                                      // ALU 是否发来算术指令
    reg  [`ILEN]     ari_insty;                                         // 指令
    reg  [`RLEN]     ari_val1, ari_val2;                                // 需要进行运算的值
    reg  [`RBID]     ari_ROB_idx;                                       // 目标 ROB 编号                
    wire             cmp_ins_flag;                                      // 是否发给 ALU 比较运算
    reg  [`ILEN]     cmp_insty;                                         // 发给 ALU 的比较运算指令
    reg  [`RLEN]     cmp_val1, cmp_val2;                                // 发给 ALU 的比较运算值
    reg  [`RBID]     cmp_ROB_idx;

    assign ari_ins_flag = ari_ready != 0;
    assign cmp_ins_flag = cmp_ready != 0;

    always @(*) begin
        ari_insty = `null6;
        ari_val1 = `null32;
        ari_val2 = `null32;
        ari_ROB_idx = 0;
        cmp_insty = `null6;
        cmp_val1 = `null32;
        cmp_val2 = `null32;
        cmp_ROB_idx = 0;
        for (i = 0; i < `RSSIZE; i = i + 1)
            if (ari_ready_pos[i])
            begin
                ari_insty = ins[i];
                ari_val1 = val1[i];
                ari_val2 = val2[i];
                ari_ROB_idx = ROB_idx[i];
            end

        for (i = 0; i < `RSSIZE; i = i + 1)
            if (cmp_ready_pos[i]) begin
                cmp_insty = ins[i];
                cmp_val1 = val1[i];
                cmp_val2 = val2[i];
                cmp_ROB_idx = ROB_idx[i];
            end

        if (!rs1_ready) begin
            if (ari_val_flag_RS && ari_val_idx_RS == reg1[`RBID]) begin
                new_rs1_ready = `True;
                new_reg1 = ari_val_RS;
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
            if (ari_val_flag_RS && ari_val_idx_RS == reg2[`RBID]) begin
                new_rs2_ready = `True;
                new_reg2 = ari_val_RS;
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
            ari_used <= `null16;
            cmp_used <= `null16;
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
                    ari_used[i] <= !insty[5];
                    cmp_used[i] <= insty[5];
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

            if (ari_ready_pos) begin
                for (i = 0; i < `RSSIZE; i = i + 1)
                    if (ari_ready_pos[i]) begin
                        used[i] <= `False;
                        ari_used[i] <= `False;
                    end
            end

            if (cmp_ready_pos) begin
                for (i = 0; i < `RSSIZE; i = i + 1)
                    if (cmp_ready_pos[i]) begin
                        used[i] <= `False;
                        cmp_used[i] <= `False;
                    end
            end

            for (i = 0; i < `RSSIZE; i = i + 1)
            if (used[i]) begin
                if (ari_val_flag_RS && !val1_ready[i] && val1[i][`RBID] == ari_val_idx_RS) begin
                    val1_ready[i] <= `True;
                    val1[i] <= ari_val_RS;
                end
                if (val_flag_LSB && !val1_ready[i] && val1[i][`RBID] == val_idx_LSB) begin
                    val1_ready[i] <= `True;
                    val1[i] <= val_LSB;
                end

                if (ari_val_flag_RS && !val2_ready[i] && val2[i][`RBID] == ari_val_idx_RS) begin
                    val2_ready[i] <= `True;
                    val2[i] <= ari_val_RS;
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
            ari_val_flag = `True;
            ari_val_idx = ari_ROB_idx;
            case (ari_insty)
                `ADD   : ari_val = ari_val1 + ari_val2;
                `ADDI  : ari_val = ari_val1 + ari_val2;
                `SUB   : ari_val = ari_val1 - ari_val2;
                `XOR   : ari_val = ari_val1 ^ ari_val2;
                `XORI  : ari_val = ari_val1 ^ ari_val2;
                `OR    : ari_val = ari_val1 | ari_val2;
                `ORI   : ari_val = ari_val1 | ari_val2;
                `AND   : ari_val = ari_val1 & ari_val2;
                `ANDI  : ari_val = ari_val1 & ari_val2;
                `SLL   : ari_val = ari_val1 << ari_val2[4:0];
                `SLLI  : ari_val = ari_val1 << ari_val2[4:0];
                `SRL   : ari_val = ari_val1 >> ari_val2[4:0];
                `SRLI  : ari_val = ari_val1 >> ari_val2[4:0];
                `SRA   : ari_val = $signed(ari_val1) >> ari_val2[4:0];
                `SRAI  : ari_val = $signed(ari_val1) >> ari_val2[4:0];
                `SLT   : ari_val = $signed(ari_val1) < $signed(ari_val2);
                `SLTI  : ari_val = $signed(ari_val1) < $signed(ari_val2);
                `SLTU  : ari_val = ari_val1 < ari_val2;
                `SLTIU : ari_val = ari_val1 < ari_val2;
                default: ari_val = `null32;
            endcase
        end
        else begin
            ari_val_flag = `False;
            ari_val_idx = `null4;
            ari_val = `null32;
        end

        if (cmp_ins_flag) begin
            cmp_val_flag = `True;
            cmp_val_idx = cmp_ROB_idx;
            case (cmp_insty)
                `BEQ   : cmp_val = cmp_val1 == cmp_val2;
                `BNE   : cmp_val = cmp_val1 != cmp_val2;
                `BLT   : cmp_val = $signed(cmp_val1) < $signed(cmp_val2);
                `BGE   : cmp_val = $signed(cmp_val1) >= $signed(cmp_val2);
                `BLTU  : cmp_val = cmp_val1 < cmp_val2;
                `BGEU  : cmp_val = cmp_val1 >= cmp_val2;
                `JALR  : cmp_val = (cmp_val1 + cmp_val2) & ~(32'b1);
                default: cmp_val = `null32;
            endcase
        end
        else begin
            cmp_val_flag = `False;
            cmp_val_idx = `null4;
            cmp_val = `null32;
        end
    end
endmodule