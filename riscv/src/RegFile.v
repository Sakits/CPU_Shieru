`include "defines.v"

module RegFile (
    input  wire             clk, rst, rdy, jp_wrong, 

    // Decoder
    input  wire [ 4: 0]     rs1, rs2, 
    output wire             reg1_flag_ID, reg2_flag_ID, 
    output wire [31: 0]     reg1_ID, reg2_ID, 

    // ROB
    input  wire             upd, write,  
    input  wire [ 3: 0]     upd_idx, write_idx, 
    input  wire [ 4: 0]     upd_rd, write_rd, 
    input  wire [31: 0]     new_val, 
    output wire [ 3: 0]     rs1_pos, rs2_pos
);
    reg  [31: 0]    reg_val     [31: 0];
    reg  [31: 0]    reg_state;
    reg  [ 3: 0]    ROB_pos     [31: 0];

    assign reg1_flag_ID = reg_state[rs1];
    assign reg2_flag_ID = reg_state[rs2];
    assign reg1_ID = reg_val[rs1];
    assign reg2_ID = reg_val[rs2];
    assign rs1_pos = ROB_pos[rs1];
    assign rs2_pos = ROB_pos[rs2];

    integer i;
    reg [31: 0] debug_now;
    always @(posedge clk) begin
        debug_now <= debug_now + 1;
        // $display("RF: ", debug_now);
        if (rst)
            debug_now <= 0;
        if (rst) begin
            reg_state <= ~(`null32);
            for (i = 0; i < 32; i = i + 1)
                reg_val[i] <= `null32;
        end
        else if (!rdy) begin
            
        end
        else begin
            // for (i = 0; i < 32; i = i + 1)
            //     $write("%h ", reg_val[i]);
            // $display;
            // $display("reg[10]:", "%h", reg_val[10], " %h", reg_state[10]);
            // $display("reg[11]:", "%h", reg_val[11], " %h", reg_state[11]);
            // $display("reg[12]:", "%h", reg_val[12], " %h", reg_state[12]);
            if (jp_wrong) begin
                reg_state <= ~(`null32);
            end
            else begin
                if (write && write_rd) begin
                    reg_val[write_rd] <= new_val;
                    reg_state[write_rd] <= (ROB_pos[write_rd] == write_idx && write_rd != upd_rd);
                end

                if (upd && upd_rd) begin
                    reg_state[upd_rd] <= `False;
                    ROB_pos[upd_rd] <= upd_idx;
                end 
            end 
        end
        
    end
    
endmodule