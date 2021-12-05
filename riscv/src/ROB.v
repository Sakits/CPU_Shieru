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

module ROB (
    input  wire             clk, rst, rdy,    
    output reg              jp_wrong,                                   // 跳转错误

    // InstFetch
    output reg  [`RLEN]     jp_pc_IF,                                   // 正确跳转到的 pc

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
    output reg              write_flag,                                 // 是否 commit 了一条指令
    output reg  [`RBID]     write_idx,                                  // commit 的 ROB 编号
    output reg  [`RIDX]     write_rd,                                   // commit 的目标寄存器
    output reg  [`RLEN]     new_val,                                    // commit 的寄存器值

    // RS
    output wire             idx_RS,                                     // 新指令在 ROB 中的位置发给 RS
    input  wire             val_flag_RS,                                // RS 是否发来更新
    input  wire [`RBID]     val_idx_RS,                                 // RS 更新对应 ROB 编号
    input  wire [`RLEN]     val_RS,                                     // RS 更新的值
    

    // LSB
    output wire             idx_LSB,                                    // 新指令在 ROB 中的位置发给 LSB
    input  wire             val_flag_LSB,                               // LSB 是否发来更新
    input  wire [`RBID]     val_idx_LSB,                                // LSB 更新对应 ROB 编号
    input  wire [`RLEN]     val_LSB,                                    // LSB 更新的值
    output reg              store_flag                                  // ROB commit，允许 LSB 中第一条 store 指令执行
);
    reg             full;                                               // ROB 是否已满
    reg  [`RBID]    front, rear;                                        // ROB 循环队列的头尾

    reg             ready       [`RBSZ];                                // 是否可以 commit
    reg             jp_check    [`RBSZ];                                // 预测跳转 / 不跳转
    reg  [`RLEN]    val         [`RBSZ];                                // ROB 中储存的值
    reg  [`RIDX]    reg_idx     [`RBSZ];                                // 目标寄存器的编号

    reg             jalr_flag;                                          // 最旧的 jalr 指令是否存在
    reg  [`RIDX]    jalr_idx;                                           // 最旧的 jalr 指令在 ROB 中的编号
    reg  [`RLEN]    jalr_pc;                                            // 最旧的 jalr 指令想跳转到哪

    assign ROB_full = full;
    assign idx_RS = rear;
    assign idx_LSB = rear;

    assign rs1_ready_ID = ready[rs1_idx];
    assign rs2_ready_ID = ready[rs2_idx];
    assign reg1_ID = ready[rs1_idx] ? val[rs1_idx] : rs1_idx;
    assign reg2_ID = ready[rs2_idx] ? val[rs2_idx] : rs2_idx;

    assign upd_flag = ins_flag ? rd : `null1;
    assign upd_idx = rear;
    assign upd_rd = rd;

    integer i;
    always @(posedge clk) begin
        if (rst || jp_wrong) begin
            jp_wrong <= `False;

            full <= `False;
            front <= `null4;
            rear <= `null4;

            for (i = 0; i < `ROBSIZE; i = i + 1) begin
                ready[i] <= `False;
                val[i] <= `null32; // 可以去掉
                reg_idx[i] <= `null5;
            end

            jalr_flag <= `False;
            jalr_idx <= `null5;
            jalr_pc <= `null32; // 可以去掉

            write_flag <= `False;
            write_idx <= `null4;
            write_rd <= `null5;
            new_val <= `null32;

            store_flag <= `False;
        end
        else if (!rdy) begin
            
        end
        else begin
            if (ins_flag) begin
                rear <= -(~rear);
                ready[rear] <= (insty == `SB || insty == `SH || insty == `SW || insty == `JAL);
                val[rear] <= jp_pc;
                jp_check[rear] <= jp_flag;
                reg_idx[rear] <= rd;

                if (insty == `JALR && jalr_flag == `False) begin
                    jalr_flag <= `True;
                    jalr_idx <= rear;
                end
            end

            full <= ready[front] ? `False : (ins_flag && (front == (-(~rear))));

            if (ready[front] || (val_flag_RS && val_idx_RS == front) || (val_flag_LSB && val_idx_LSB == front)) begin
                front <= -(~front);

                if (insty == `SB || insty == `SH || insty == `SW) begin
                    store_flag <= `True;
                    write_flag <= `False;
                end
                else if (insty[5]) begin
                    if (insty == `JALR) begin
                        jp_wrong <= `True;
                        jp_pc_IF <= ready[front] ? jalr_pc : val_RS;

                        write_flag <= `True;
                        write_idx <= front;
                        write_rd <= rd;
                        new_val <= val[front];

                        store_flag <= `False;
                    end 
                    else if (insty == `JAL) begin
                        write_flag <= `True;
                        write_idx <= front;
                        write_rd <= rd;
                        new_val <= val[front];

                        store_flag <= `False;
                    end
                    else if ((ready[front] && jp_check[front]) || (jp_check[front] != val_RS[0])) begin
                        jp_wrong <= `True;
                        jp_pc_IF <= val[front];
                        
                        write_flag <= `False;
                        store_flag <= `False;
                    end
                end
                else begin
                    write_flag <= `True;
                    write_idx <= front;
                    write_rd <= rd;
                    if (ready[front]) begin
                        new_val <= val[front];
                    end else if (val_flag_RS) begin
                        new_val <= val_RS;
                    end else begin
                        new_val <= val_LSB;
                    end

                    store_flag <= `False;
                end
            end
            else begin
                store_flag <= `False;
                write_flag <= `False;
            end

            if (val_flag_RS) begin
                ready[val_idx_RS] <= `True;
                if (insty[5]) begin
                    jp_check[val_idx_RS] <= jp_check[val_idx_RS] != val_RS[0];
                end else begin
                    val[val_idx_RS] <= val_RS;
                end
                
                if (insty == `JALR)
                    jalr_pc <= val_RS;
            end

            if (val_flag_LSB) begin
                ready[val_idx_LSB] <= `True;
                val[val_idx_LSB] <= val_LSB;
            end
        end
    end
    
endmodule