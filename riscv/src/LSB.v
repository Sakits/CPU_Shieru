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
    output wire             LSB_full, 

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
    assign next_addr = val1[-(~front)] + val_imm[-(~front)];

    assign LSB_full = val_flag ? (full && ins_flag) : (full || (ins_flag && (front == (-(~rear)))));

    assign val_flag_LSB = val_flag && !(ins[front][2] && ins[front][1:0] != 0);
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

    // always @(*) begin
    //     // $display("commit_cnt", commit_cnt);
    //     for (i = 0; i < 16; i = i + 1) begin
    //         $display("")
    //     end
    // end

    reg             new_rs1_ready, new_rs2_ready;                       // 当前输入指令的 rs1 和 rs2 是否拿到真值
    reg  [`RLEN]    new_reg1, new_reg2;                                 // 当前输入指令的 rs1 和 rs2 的值

    always @(*) begin
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

    reg [31: 0] debug_now;
    always @(posedge clk) begin
        // if (ins_flag && new_reg1 == 18'h30000 && insty[2] && insty[1:0] != 0) begin
        //     $display("debug_now:", "%h", debug_now);
        //     $display("insty:", "%h", insty);
        //     $display("rear:", "%h", rear);
        //     $display("rs1_ready:", "%h", new_rs1_ready);
        //     $display("reg1:", "%h", new_reg1);
        //     $display("rs2_ready:", "%h", new_rs2_ready);
        //     $display("reg2:", "%h", new_reg2);
        //     $display;
        // end

        // if (addr_out == 18'h1FFC4) begin
        //     $display("debug_now:", "%h", debug_now);
        //     $display("val_flag_MC:", "%h", val_flag_MC);
        //     $display("insty_MC:", "%h", insty_MC);
        //     $display("addr_out:  ", "%h",  addr_out);
        //     $display("val_out:  ", "%h",  val_out);
        //     $display("front:", "%h", ROB_idx[front]);
        //     $display("val1:", "%h", val1[front]);
        //     $display("val2:", "%h", val2[front]);
        //     $display("imm:", "%h", val_imm[front]);
        //     $display;
        // end


        debug_now <= debug_now + 1;
        // $display("LSB: ", debug_now);
        if (rst)
            debug_now <= 0;
        if (rst) begin
            full <= `False;
            front <= `null4;
            rear <= `null4;
            commit_cnt <= `null4;
            // $display("commit_cnt_new:", commit_cnt);
            val1_ready <= `null16;
            val2_ready <= `null16;
            iscommit <= `null16;
        end
        else if (!rdy) begin
            
        end
        else if (jp_wrong) begin
            full <= !val_flag && commit_cnt == `LSBSIZE;
            rear <= front + commit_cnt + (val_flag && !(ins[front][2] && ins[front][1:0] != 0)); 
            
            if (val_flag)
                front <= -(~front);
            commit_cnt <= commit_cnt - (val_flag && ins[front][2] && ins[front][1:0] != 0);
        end 
        else begin
            full <= val_flag ? (full && ins_flag) : (full || (ins_flag && (front == (-(~rear)))));

            if (ins_flag) begin
                rear <= -(~rear);
                val1_ready[rear] <= new_rs1_ready;
                val2_ready[rear] <= new_rs2_ready;
                ROB_idx[rear] <= new_ROB_idx;
                iscommit[rear] <= `False;
                ins[rear] <= insty;

                val1[rear] <= new_reg1;
                val2[rear] <= new_reg2;
                val_imm[rear] <= imm;
            end

            if (val_flag)
                front <= -(~front);

            commit_cnt <= commit_cnt - (val_flag && ins[front][2] && ins[front][1:0] != 0) + store_flag;

            if (store_flag) begin
                iscommit[front + commit_cnt] <= `True;
                // $display("front:", front);
                // $display("commit_cnt:", commit_cnt); 
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