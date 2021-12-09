`include "defines.v"

module ROB (
    input  wire             clk, rst, rdy,    
    output reg              jp_wrong,                                   // 跳转错误

    // InstFetch
    output reg  [`RLEN]     jp_pc_IF,                                   // 正确跳转到的 pc

    // CDB
    output reg  [`RBID]     front, rear,                                // ROB 的头尾

    // Decoder
    input  wire             jp_flag, ins_flag,                          // 预测跳转为 1，不跳转为 0； 指令是否有效
    input  wire [`RIDX]     rd,                                         // 目标寄存器
    input  wire [`ILEN]     insty,                                      // 指令
    input  wire [`RLEN]     jp_pc,                                      // IF 阶段算好的 pc
    output wire             ROB_full, rs1_ready_ID, rs2_ready_ID,       // ROB 是否满了； rs1，rs2 是否已经拿到真正的值，是为 1，否则为 0
    output wire [`RLEN]     reg1_ID, reg2_ID,                           // 两个寄存器的值，若没拿到真正的值，则为 ROB 编号

    // RegFile 
    input  wire [`RBID]     rs1_idx, rs2_idx,                           // rs1，rs2 对应的 ROB 编号
    output wire             upd_flag,                                   // 是否有新的指令加入 ROB
    output wire [`RBID]     upd_idx,                                    // 新指令在 ROB 的位置
    output wire [`RIDX]     upd_rd,                                     // 新指令的目标寄存器
    output reg              write_flag,                                 // 是否 commit 了一条指令写寄存器
    output wire [`RBID]     write_idx,                                  // commit 的 ROB 编号
    output wire [`RIDX]     write_rd,                                   // commit 的目标寄存器
    output wire [`RLEN]     new_val,                                    // commit 的寄存器值

    // RS
    input  wire             val_flag_RS,                                // RS 是否发来更新
    input  wire [`RBID]     val_idx_RS,                                 // RS 更新对应 ROB 编号
    input  wire [`RLEN]     val_RS,                                     // RS 更新的值
    

    // LSB
    input  wire             val_flag_LSB,                               // LSB 是否发来更新
    input  wire [`RBID]     val_idx_LSB,                                // LSB 更新对应 ROB 编号
    input  wire [`RLEN]     val_LSB,                                    // LSB 更新的值
    output reg              store_flag                                  // ROB commit，允许 LSB 中第一条 store 指令执行
);
    reg             full;                                               // ROB 是否已满

    reg  [`RBSZ]    ready;                                              // 是否可以 commit
    reg  [`RBSZ]    jp_check;                                           // 预测跳转 / 不跳转
    reg  [`RLEN]    val         [`RBSZ];                                // ROB 中储存的值
    reg  [`RIDX]    reg_idx     [`RBSZ];                                // 目标寄存器的编号
    reg  [`ILEN]    ins         [`RBSZ];                                // 保存的指令

    reg             jalr_flag;                                          // 最旧的 jalr 指令是否存在
    reg  [`RIDX]    jalr_idx;                                           // 最旧的 jalr 指令在 ROB 中的编号
    reg  [`RLEN]    jalr_pc;                                            // 最旧的 jalr 指令想跳转到哪

    assign ROB_full = full;

    assign rs1_ready_ID = ready[rs1_idx];
    assign rs2_ready_ID = ready[rs2_idx];
    assign reg1_ID = ready[rs1_idx] ? val[rs1_idx] : rs1_idx;
    assign reg2_ID = ready[rs2_idx] ? val[rs2_idx] : rs2_idx;

    always @(*) begin
        $display("rs2_idx:", rs2_idx);
        $display("ready:", ready[rs2_idx]);
        $display("reg2:", val[rs2_idx]);
    end

    assign upd_flag = ins_flag ? (rd != 0) : `False;
    assign upd_idx = rear;
    assign upd_rd = rd;

    assign write_idx = front;
    assign write_rd = reg_idx[front];
    assign new_val = val[front];

    integer i;

    reg [31: 0] debug_now;
    always @(posedge clk) begin
        debug_now <= debug_now + 1;
        // $display("ROB: ", debug_now);
        if (rst)
            debug_now <= 0;

        if (rst || jp_wrong) begin
            jp_wrong <= `False;
            jp_pc_IF <= `null32;

            full <= `False;
            front <= `null4;
            rear <= `null4;

            jalr_flag <= `False;
            jalr_idx <= `null5;
            jalr_pc <= `null32; // 可以去掉

            ready <= `null16;
            write_flag <= `False;
            store_flag <= `False;
            // ready <= ~(`null16);
        end
        else if (!rdy) begin
            
        end
        else begin
            full <= ready[front] ? `False : (ins_flag && (front == (-(~rear))));

            if (ins_flag) begin
                rear <= -(~rear);
                ready[rear] <= (insty == `SB || insty == `SH || insty == `SW || insty == `JAL || insty == `LUI);
                // $display("rear:", rear);
                // $display("jp_flag:", jp_flag);
                jp_check[rear] <= jp_flag;
                val[rear] <= jp_pc;
                reg_idx[rear] <= rd;
                ins[rear] <= insty;

                if (insty == `JALR && jalr_flag == `False) begin
                    jalr_flag <= `True;
                    jalr_idx <= rear;
                    jalr_pc <= `null32; // 可以去掉
                end
            end

            if (full || front != rear) begin
                if (ready[front] || (val_flag_RS && val_idx_RS == front) || (val_flag_LSB && val_idx_LSB == front)) begin
                    front <= -(~front);
                    write_flag <= ready[front] && (!ins[front][5] || ins[front] == `JAL || ins[front] == `JALR);
                    store_flag <= (ins[front] == `SB || ins[front] == `SH || ins[front] == `SW);
                    $display("frontt:", front);
                    $display("ready:", ready[front]);
                    $display("jpcheck:", jp_check[front]);
                    $display("val:", val_RS[0]);
                    if (ins[front] == `JALR || (ins[front][5]) && (ready[front] && jp_check[front] || (!ready[front] && jp_check[front] != val_RS[0]))) begin                      
                        jp_wrong <= `True;
                        jp_pc_IF <= ins[front] == `JALR ? (ready[front] ? jalr_pc : val_RS) : val[front];
                    end
                end
            end

            if (val_flag_RS) begin
                ready[val_idx_RS] <= `True;
                if (ins[val_idx_RS][5] && !ins[val_idx_RS][4]) begin
                    $display("val_idx_RSjp:", val_idx_RS);
                    $display("val_idx_RSjp:", jp_check[val_idx_RS]);
                    $display("val_idx_RSjp:", val_RS[0]);
                    jp_check[val_idx_RS] <= jp_check[val_idx_RS] != val_RS[0];
                end 
                else begin
                    $display("val_idx_RS:", val_idx_RS);
                    val[val_idx_RS] <= val_RS;
                end
                
                if (ins[val_idx_RS] == `JALR)
                    jalr_pc <= val_RS;
            end

            if (val_flag_LSB) begin
                ready[val_idx_LSB] <= `True;
                val[val_idx_LSB] <= val_LSB;
            end
        end
    end
    
endmodule