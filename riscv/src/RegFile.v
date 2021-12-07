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
    always @(posedge clk) begin
        if (rst) begin
            reg_state <= ~(`null32);
        end
        else if (!rdy) begin
            
        end
        else begin
            if (jp_wrong) begin
                reg_state <= ~(`null32);
            end
            else if (upd && upd_rd) begin
                reg_state[upd_rd] <= `False;
                ROB_pos[upd_rd] <= upd_idx;
            end 
            else if (write && write_rd) begin
                reg_state[write_rd] <= (ROB_pos[write_rd] == write_idx);
            end

            if (write && write_rd) begin
                reg_val[write_rd] <= new_val; 
            end
        end
        
    end
    
endmodule