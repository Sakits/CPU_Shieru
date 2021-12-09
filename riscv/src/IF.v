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
    output wire [31: 0]     pc_out, 
    output wire             is_stall_IC
);
    reg  [31: 0]    imm;

    always @(*) begin
        // $display("%h", ins);
        // $display(pc_out);
        case (ins[6:0])
            `LUIOP : imm = {ins[31:12], 12'b0};                                 
            `JALROP: imm = {{20{ins[31]}}, ins[31:20]};
            `JALOP : imm = {{12{ins[31]}}, ins[19:12], ins[20], ins[30:21]} << 1;
            default: imm = {{20{ins[31]}}, ins[7], ins[31:25], ins[11:8]} << 1;  
        endcase
    end

    wire [ 6: 0]    opcode = ins[6:0];
    reg  [31: 0]    pc;
    assign is_stall_IC = (opcode == `JALOP && ins_flag);
    assign pc_out = ins_flag ? pc + 4 : pc;
    assign jp_flag_ID = 4 == imm;
    assign jp_pc_ID = (opcode == `JALOP || opcode == `JALROP) ? pc + 4
                    : (opcode == `LUIOP) ? imm
                    : pc + imm;
    assign ins_flag_ID = ins_flag;
    assign ins_ID = ins;

    // always @(*) begin
        // $display("imm: ", imm);
        // $display("ins_flag:", ins_flag);
        // $display("pc_out:", pc_out);
    // end
    
    reg  [31: 0] debug_now;
    always @(posedge clk) begin
        debug_now <= debug_now + 1;
        // $display("IF: ", debug_now);
        if (rst) begin
            debug_now <= 0;
            pc <= `null32;
        end 
        else if (!rdy) begin
            
        end
        else if (jp_wrong) 
            pc <= jp_pc;
        else if (stall_ID) begin
            
        end
        else if (ins_flag) begin
            pc <= pc + ((opcode == `JALOP) ? imm : 4);
            // $display("pc:", pc);
        end
    end

endmodule