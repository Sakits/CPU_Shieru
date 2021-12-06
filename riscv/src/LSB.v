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

module LSB (
    input  wire             clk, rst, rdy, 
    input  wire             jp_wrong,                                   // 跳转错误

    // CDB
    output reg              val_flag_LSB, 
    output reg  [`RBID]     val_idx_LSB, 
    output reg  [`RLEN]     val_LSB, 

    // Decoder
    input  wire             ins_flag, 
    input  wire [ 2: 0]     insty, 

    // ROB
    input  wire [`RBID]     new_ROB_idx,
    input  wire             load_flag,  
    input  wire             store_flag, 

    // RS
    input  wire             val_flag_RS, 
    input  wire [`RBID]     val_idx_RS, 
    input  wire [`RLEN]     val, 

    // MemCtrl
    input wire              val_flag_MEM, 
    input wire  [ 7: 0]     
);

    reg  [`LSID]    front, rear;

    reg             rs1_ready, rs2_ready;
    reg  [`RLEN]    reg1, reg2, imm;



    always @(posedge clk) begin
        if (rst) begin
            val_flag_LSB <= `False;
            val_idx_LSB <= `null4;
            val_LSB <= `null32;

            mem_dout <= 8'b0;
            mem_a <= `null32;
            mem_wr <= `null1;

            front <= `null4;
            rear <= `null4;
            rs1_ready <= `False;
            rs2_ready <= `False;
            reg1 <= `null32;
            reg2 <= `null32;
            imm <= `null32;
        end
        else if (!rdy) begin
            
        end
        else if (jp_wrong) begin
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
        end begin
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
        always @(posedge clk) begin
            if (rst || jp_wrong) begin
                ari_ins_flag <= `False;
                ari_insty <= `null6;
                ari_val1 <= `null32; // 可以去掉
                ari_val2 <= `null32; // 可以去掉
    
                for (i = 0; i < `RSSIZE; i = i + 1) 
                    used[i] <= `False;
            end
            else if (!rdy) begin
                
            end
            else begin
                if (ins_flag) begin
                    ins[idle_pos] <= insty;
                    used[idle_pos] <= `True;
                    ROB_idx[idle_pos] <= new_ROB_idx;
    
                    val1[idle_pos] <= new_reg1;
                    val1_ready[idle_pos] <= new_rs1_ready;
    
                    if (insty == `JALR || (!insty[5] && insty[0])) begin
                        val2[idle_pos] <= imm;
                        val2_ready[idle_pos] <= `True;    
                    end
                    else begin
                        val2[idle_pos] <= new_reg2;
                        val2_ready[idle_pos] <= new_rs2_ready;
                    end    
                end
    
                if (ready_pos_lowbit) begin
                    ari_ins_flag <= `True;
                    ari_insty <= ins[ready_pos];
                    ari_val1 <= val1[ready_pos];
                    ari_val2 <= val2[ready_pos];
                    ari_ROB_idx <= ROB_idx[ready_pos];
    
    
                    if (!val1_ready[ready_pos]) begin
                        if (val_flag_RS && val_idx_RS == reg1) 
                            ari_val1 <= val_RS;
                        else 
                            ari_val1 <= val_LSB;
                    end
                    else
                        ari_val1 <= val1[ready_pos];
    
                    if (!val2_ready[ready_pos]) begin
                        if (val_flag_RS && val_idx_RS == reg2)
                            ari_val2 <= val_RS;
                        else
                            ari_val2 <= val_LSB;
                    end
                    else
                        ari_val2 <= val2[ready_pos];
                end
                else
                    ari_ins_flag <= `False;
    
                for (i = 0; i < 16; i = i + 1)
                if (used[i]) begin
                    if (val_flag_RS && !val1_ready[i] && val1[i][`RBID] == val_idx_RS) begin
                        val1_ready[i] <= `True;
                        val1[i] <= val_RS;
                    end
                    else if (val_flag_LSB && !val1_ready[i] && val1[i][`RBID] == val_idx_LSB) begin
                        val1_ready[i] <= `True;
                        val1[i] <= val_LSB;
                    end
    
                    if (val_flag_RS && !val2_ready[i] && val2[i][`RBID] == val_idx_RS) begin
                        val2_ready[i] <= `True;
                        val2[i] <= val_RS;
                    end
                    else if (val_flag_LSB && !val2_ready[i] && val2[i][`RBID] == val_idx_LSB) begin
                        val2_ready[i] <= `True;
                        val2[i] <= val_LSB;
                    end
                end
            end
        end
        end
    end
    
endmodule