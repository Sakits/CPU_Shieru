`include "defines.v"

module LSB (
    input  wire             clk, rst, rdy, 
    input  wire             jp_wrong,                                   // 跳转错误

    // CDB
    output wire             val_flag_LSB, 
    output wire [`RBID]     val_idx_LSB, 
    output wire [`RLEN]     val_LSB, 

    // Decoder
    input  wire             ins_flag, 
    input  wire [ 2: 0]     insty, 
    input  wire             rs1_ready, rs2_ready, 
    input  wire [`RLEN]     reg1, reg2, imm, 

    // ROB
    input  wire [`RBID]     new_ROB_idx,
    input  wire [`RBID]     ROB_front,  
    input  wire             store_flag, 

    // RS
    input  wire             val_flag_RS, 
    input  wire [`RBID]     val_idx_RS, 
    input  wire [`RLEN]     val_RS, 

    // MemCtrl
    input  wire              val_flag, 
    input  wire [31: 0]      val_in, 
    output wire              val_flag_MC, 
    output wire [ 2: 0]      insty_MC, 
    output wire [31: 0]      addr_out, 
    output wire [31: 0]      val_out 
);

    reg  [`LSID]    full, front, rear, commit_cnt;

    reg  [ 2: 0]    ins         [`LSSZ];
    reg  [`LSSZ]    val1_ready, val2_ready, iscommit;
    reg  [`RLEN]    val1        [`LSSZ];
    reg  [`RLEN]    val2        [`LSSZ];
    reg  [`RLEN]    val_imm     [`LSSZ];
    reg  [`RBID]    ROB_idx     [`LSSZ];

    reg             now_val_flag_MC, next_val_flag_MC;
    wire [31: 0]    now_addr, next_addr;
    assign now_addr = val1[front] + val_imm[front];
    assign next_addr = val1[-(~front)] + val_imm[front];

    assign val_flag_LSB = val_flag;
    assign val_idx_LSB = ROB_idx[front];
    assign val_LSB = val_in;

    assign val_flag_MC = val_flag ? next_val_flag_MC : now_val_flag_MC;
    assign insty_MC = val_flag ? ins[-(~front)] : ins[front];
    assign addr_out = val_flag ? next_addr : now_addr;
    assign val_out = val_flag ? val2[-(~front)] : val2[front];

    always @(*) begin
        if (full || front != rear) begin
            if (ins[front] == `SB || ins[front] == `SH || ins[front] == `SW) 
                now_val_flag_MC = iscommit[front];
            else
                now_val_flag_MC = (now_addr[17:16] == 2'b11) ? (ROB_idx[front] == ROB_front) : `True;
        end
        else 
            now_val_flag_MC = `False;

        if ((full || front != rear) && -(~front) != rear) begin
            if (ins[-(~front)] == `SB || ins[-(~front)] == `SH || ins[-(~front)] == `SW) 
                next_val_flag_MC = iscommit[-(~front)];
            else
                next_val_flag_MC = (next_addr[17:16] == 2'b11) ? (ROB_idx[-(~front)] == ROB_front) : `True;
        end
        else 
            next_val_flag_MC = `False;
    end

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            full <= `False;
            front <= `null4;
            rear <= `null4;
            commit_cnt <= `null4;
            val1_ready <= `null16;
            val2_ready <= `null16;
            iscommit <= `null16;
        end
        else if (!rdy) begin
            
        end
        else if (jp_wrong) begin
            full <= commit_cnt == 0;
            rear <= front + commit_cnt;
            val1_ready <= `null16;
            val2_ready <= `null16;      
        end begin
            full <= val_flag ? `False : (ins_flag && (front == (-(~rear))));

            if (ins_flag) begin
                rear <= -(~rear);
                val1_ready[rear] <= rs1_ready;
                val2_ready[rear] <= rs2_ready;
                ROB_idx[rear] <= new_ROB_idx;
                iscommit[rear] <= `False;
                ins[rear] <= insty;

                val1[rear] <= reg1;
                val2[rear] <= reg2;
                val_imm[rear] <= imm;
            end
            
            if (val_flag) begin
                front <= -(~front);
                commit_cnt = commit_cnt - iscommit[front];
            end

            for (i = 0; i < `LSBSIZE; i = i + 1)
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