`include "defines.v"

module ICache (
    input  wire             clk, rst, rdy, 
    input  wire             jp_wrong,                                   // 跳转错误

    // IF
    input  wire [31: 0]     pc, 
    output reg              ins_flag_IF, 
    output reg  [31: 0]     ins_IF, 

    // MemCtrl
    input  wire             ins_flag, 
    input  wire [31: 0]     ins, 
    output wire             ins_flag_MC, 
    output wire [31: 0]     pc_MC
);

    reg  [`ICSZ - 1: 0]         valid;
    reg  [`TGID]    tag         [`ICSZ - 1: 0];
    reg  [31: 0]    cache       [`ICSZ - 1: 0];

    wire is_hit = valid[pc[`ICID]] && tag[pc[`ICID]] == pc[`TGID];
    assign ins_flag_MC = !is_hit && !ins_flag;
    assign pc_MC = pc;

    // always @(*) begin
        // $display("pc: ", "%h", pc);
        // $display("ishit:", is_hit);
        // $display("cache:", "%h", cache[pc[`ICID]][17:0]);
        // $display("ins_flag_IF:", ins_flag_IF);
        // $display("pc_MC:", pc_MC);
    // end

    reg [31: 0] debug_now;
    always @(posedge clk) begin
        debug_now <= debug_now + 1;
        // $display("IC: ", debug_now);
        if (rst)
            debug_now <= 0;
        if (rst) begin
            valid <= 0;
            ins_flag_IF <= `False;
        end
        else if (!rdy) begin
            
        end
        else begin
            if (!jp_wrong) begin
                if (is_hit) begin
                    ins_flag_IF <= `True;
                    ins_IF <= cache[pc[`ICID]];
                end
                else begin
                    ins_flag_IF <= ins_flag;
                    ins_IF <= ins; 
                end
            end
            else
                ins_flag_IF <= `False;

            if (ins_flag) begin
                valid[pc[`ICID]] <= `True;
                cache[pc[`ICID]] <= ins;
                tag[pc[`ICID]] <= pc[`TGID];
            end
        end
    end

endmodule