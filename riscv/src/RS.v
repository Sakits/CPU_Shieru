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
    output wire             ari_ins_flag,                               // 是否发给 ALU 算术运算
    output wire [`ILEN]     ari_insty,                                  // 发给 ALU 的算术运算指令
    output wire [`RLEN]     ari_val1, ari_val2,                         // 发给 ALU 的算术运算值
    output wire [`RBID]     ari_ROB_idx,                                // 发给 ALU 的算术运算目标 ROB 编号
    // output reg              cmp_ins_flag,                            // 是否发给 ALU 比较运算
    // output reg  [`ILEN]     cmp_insty,                               // 发给 ALU 的比较运算指令
    // output reg  [`RLEN]     cmp_val1, cmp_val2,                      // 发给 ALU 的比较运算值

    // LSB
    input  wire             val_flag_LSB,                               // LSB 是否发来更新
    input  wire [`RBID]     val_idx_LSB,                                // LSB 更新对应 ROB 编号
    input  wire [`RLEN]     val_LSB                                     // LSB 更新的值
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
    reg  [`RSID]    idle_pos;                                           

    wire [`RSSZ]    ready_state = used & val1_ready & val2_ready;       // RS 中可以运算的所有位置
    wire [`RSSZ]    ready_pos_lowbit = ready_state & (-ready_state);    // RS 中最低位可以运算的位置
    reg  [`RSID]    ready_pos;

    reg             pre_ready_pos;

    assign ari_ins_flag = ready_pos_lowbit != 0;
    assign ari_insty = ins[ready_pos];
    assign ari_val1 = val1[ready_pos];
    assign ari_val2 = val2[ready_pos];
    assign ari_ROB_idx = ROB_idx[ready_pos];

    always @(*) begin
        case (ready_pos_lowbit)
            16'b1000000000000000: ready_pos = 4'd15;
            16'b0100000000000000: ready_pos = 4'd14;
            16'b0010000000000000: ready_pos = 4'd13;
            16'b0001000000000000: ready_pos = 4'd12;
            16'b0000100000000000: ready_pos = 4'd11;
            16'b0000010000000000: ready_pos = 4'd10;
            16'b0000001000000000: ready_pos = 4'd9;
            16'b0000000100000000: ready_pos = 4'd8;
            16'b0000000010000000: ready_pos = 4'd7;
            16'b0000000001000000: ready_pos = 4'd6;
            16'b0000000000100000: ready_pos = 4'd5;
            16'b0000000000010000: ready_pos = 4'd4;
            16'b0000000000001000: ready_pos = 4'd3;
            16'b0000000000000100: ready_pos = 4'd2;
            16'b0000000000000010: ready_pos = 4'd1;
            16'b0000000000000001: ready_pos = 4'd0;
            default: ready_pos = 4'd0;
        endcase

        case (idle)
            16'b1000000000000000: idle_pos = 4'd15;
            16'b0100000000000000: idle_pos = 4'd14;
            16'b0010000000000000: idle_pos = 4'd13;
            16'b0001000000000000: idle_pos = 4'd12;
            16'b0000100000000000: idle_pos = 4'd11;
            16'b0000010000000000: idle_pos = 4'd10;
            16'b0000001000000000: idle_pos = 4'd9;
            16'b0000000100000000: idle_pos = 4'd8;
            16'b0000000010000000: idle_pos = 4'd7;
            16'b0000000001000000: idle_pos = 4'd6;
            16'b0000000000100000: idle_pos = 4'd5;
            16'b0000000000010000: idle_pos = 4'd4;
            16'b0000000000001000: idle_pos = 4'd3;
            16'b0000000000000100: idle_pos = 4'd2;
            16'b0000000000000010: idle_pos = 4'd1;
            16'b0000000000000001: idle_pos = 4'd0;
            default: idle_pos = 4'd0;
        endcase

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
        else if (!rdy) begin
            
        end
        else begin
            if (ins_flag) begin
                used[idle_pos] <= `True;
                ins[idle_pos] <= insty;
                ROB_idx[idle_pos] <= new_ROB_idx;

                val1[idle_pos] <= new_reg1;
                val1_ready[idle_pos] <= new_rs1_ready;

                if (insty == `JALR || (!insty[5] && !insty[0] && insty != `SUB)) begin
                    val2[idle_pos] <= imm;
                    val2_ready[idle_pos] <= `True;    
                end
                else begin
                    val2[idle_pos] <= new_reg2;
                    val2_ready[idle_pos] <= new_rs2_ready;
                end    
            end

            if (ready_pos_lowbit) begin
                used[ready_pos] <= `False;
                pre_ready_pos <= ready_pos; 
            end

            for (i = 0; i < `RSSIZE; i = i + 1)
            begin
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
endmodule