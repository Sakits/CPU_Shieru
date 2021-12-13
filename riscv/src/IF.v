`include "defines.v"

module IF (
    input  wire             clk, rst, rdy, 

    // ROB
    input  wire             jp_wrong,
    input  wire [31: 0]     jp_pc, 
    input  wire             jp_commit, 
    
    // Decoder
    input  wire             stall_ID, 
    output wire             ins_flag_ID, 
    output wire [31: 0]     ins_ID, 
    output reg              jp_flag_ID, 
    output reg  [31: 0]     jp_pc_ID, 
    
    // ICache
    input  wire             ins_flag, 
    input  wire [31: 0]     ins, 
    output reg  [31: 0]     pc_out
);
    reg  [31: 0]    imm;
    reg  [ 1: 0]    BHB         [`BHBSZ - 1: 0];
    reg  [`BHBID]   jp_queue    [`RBSZ];
    reg  [`RBID]    front, rear;

    always @(*) begin
        // $display("%h", ins);
        // $display(pc_out);
        case (ins[6:0])
            `AUIPCOP: imm = {ins[31:12], 12'b0};
            `LUIOP  : imm = {ins[31:12], 12'b0};                                 
            `JALROP : imm = {{20{ins[31]}}, ins[31:20]};
            `JALOP  : imm = {{12{ins[31]}}, ins[19:12], ins[20], ins[30:21]} << 1;
            default: imm = {{20{ins[31]}}, ins[7], ins[30:25], ins[11:8]} << 1;  
        endcase
    end

    wire [ 6: 0]    opcode = ins[6:0];
    reg  [31: 0]    pc;
    assign ins_flag_ID = ins_flag;
    assign ins_ID = ins;

    always @(*) begin
        if (!ins_flag || stall_ID) begin
            pc_out = pc;
            jp_flag_ID = `False;
            jp_pc_ID = pc; 
        end
        else begin
            // $display("pc_out:", pc_out);
            // $display("ins:", ins);
            // $display("ins_flag:", ins_flag);
            case (opcode)
                `BRANCHOP   : begin
                    if (BHB[pc[`BHBID]][1]) begin
                        pc_out = pc + imm;
                        jp_flag_ID = `True;
                        jp_pc_ID = pc + 4;
                    end
                    else 
                    begin
                        pc_out = pc + 4;
                        jp_flag_ID = `False;
                        jp_pc_ID = pc + imm;
                    end
                end 
                `JALOP      : begin
                    pc_out = pc + imm;
                    jp_flag_ID = 4 == imm;
                    jp_pc_ID = pc + 4;
                end
                `JALROP     : begin
                    pc_out = pc + 4;
                    jp_flag_ID = 4 == imm;
                    jp_pc_ID = pc + 4;
                end
                `LUIOP      : begin
                    pc_out = pc + 4;
                    jp_flag_ID = 4 == imm;
                    jp_pc_ID = imm;
                end
                default     :  begin
                    pc_out = pc + 4;
                    jp_flag_ID = 4 == imm;
                    jp_pc_ID = pc + imm;
                end
            endcase
        end
    end

    // always @(*) begin
    //     $display("pc+imm: ", pc + imm);
    //     $display("ins_flag:", ins_flag);
    //     $display("pc_out:", pc_out);
    // end
    reg  [31: 0]    debug_now;//, right_cnt, failed_cnt;

    integer i;
    always @(posedge clk) begin
        // $display("IF: ", ins_flag, " ", stall_ID);
        if (rst) begin
            // right_cnt <= 0;
            // failed_cnt <= 0; 
            debug_now <= `null32;
        end
        else begin
            debug_now <= debug_now + 1;
        end
        if (rst) begin
            pc <= `null32;
            for (i = 0; i < `BHBSZ; i = i + 1)
                BHB[i] <= 2'b01;
            front <= `null4;
            rear <= `null4;
        end 
        else if (!rdy) begin
            
        end
        else if (jp_wrong) begin
            pc <= jp_pc; 

            if (jp_commit) begin
                // failed_cnt <= failed_cnt + 1;
                case (BHB[jp_queue[front]])
                    2'b00 : BHB[jp_queue[front]] <= 2'b01;
                    2'b01 : BHB[jp_queue[front]] <= 2'b10;
                    2'b10 : BHB[jp_queue[front]] <= 2'b01;
                    2'b11 : BHB[jp_queue[front]] <= 2'b10;
                endcase
            end

            front <= `null4;
            rear <= `null4;
        end
        else if (stall_ID) begin
            
        end
        else if (ins_flag) begin
            // $display("pc:", pc);
            case (opcode)
                `BRANCHOP   : begin
                    if (BHB[pc[`BHBID]][1])
                        pc <= pc + imm;
                    else 
                        pc <= pc + 4;
                end 
                `JALOP      : pc <= pc + imm;
                `JALROP     : pc <= pc + 4;
                default     : pc <= pc + 4;
            endcase

            if (opcode == `BRANCHOP) begin
                rear <= -(~rear);
                jp_queue[rear] <= pc[`BHBID];
            end
            // $display("pc:", pc);
        end

        if (!rst && rdy && !jp_wrong && jp_commit) begin
            // right_cnt <= right_cnt + 1;
            // $display("right: ", right_cnt, " failed: ", failed_cnt);
            front <= -(~front);
            case (BHB[jp_queue[front]])
                2'b01 : BHB[jp_queue[front]] <= 2'b00;
                2'b10 : BHB[jp_queue[front]] <= 2'b11;
            endcase
        end
    end

endmodule