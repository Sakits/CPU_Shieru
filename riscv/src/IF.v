`include "defines.v"

module IF (
    input  wire             clk, rst, rdy, 

    // ROB
    input  wire             jp_wrong,
    input  wire [31: 0]     jp_pc, 
    
    // Decoder
    input  wire             stall_ID, 
    output wire             ins_flag_ID, jp_flag_ID, 
    output wire [31: 0]     ins_ID, jp_pc_ID,  
    
    // ICache
    input  wire             ins_flag, 
    input  wire [31: 0]     ins, 
    output wire [31: 0]     pc_out
);
    reg  [31: 0]    imm;

    always @(*) begin
        if (ins[6]) begin
            if (ins[2]) 
                imm = {{12{ins[31]}}, ins[19:12], ins[20], ins[30:21]} << 1;
            else
                imm = {{20{ins[31]}}, ins[7], ins[31:25], ins[11:8]} << 1;
        end
        else
            imm <= ins[31:12] << 12;     
    end

    wire [ 6: 0]    opcode = ins[6:0];
    reg  [31: 0]    pc;
    wire [31: 0]    next_pc = (opcode == `JALOP) ? pc + imm : pc + 4;
    assign pc_out = ins_flag ? next_pc : pc;
    assign jp_flag_ID = 4 == imm;
    assign jp_pc_ID = (opcode == `JALOP || opcode == `JALROP) ? pc + 4
                    : (opcode == `LUIOP) ? pc
                    : pc + imm;
    assign ins_flag_ID = ins_flag;
    assign ins_ID = ins;

    always @(posedge clk) begin
        if (rst) begin
            pc <= `null32;
        end 
        else if (!rdy) begin
            
        end
        else if (jp_wrong) 
            pc <= jp_pc;
        else if (stall_ID) begin
            
        end
        else if (ins_flag) 
            pc <= next_pc;
    end

endmodule