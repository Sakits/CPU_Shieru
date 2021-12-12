`include "defines.v"

module ICache (
    input  wire             clk, rst, rdy, 
    input  wire             jp_wrong,                                   // 跳转错误

    // IF
    input  wire [31: 0]     pc, 
    input  wire             is_stall, 
    output wire             ins_flag_IF, 
    output wire [31: 0]     ins_IF, 

    // MemCtrl
    input  wire             ins_flag, 
    input  wire [31: 0]     ins, 
    output wire             ins_flag_MC, 
    output wire [31: 0]     pc_MC
);

    reg  [`ICSZ]    valid;
    reg  [`TGID]    tag         [`ICSZ];
    reg  [31: 0]    cache       [`ICSZ];
    reg             cache_hit;
    reg  [31: 0]    hit_ins;
    reg  [`ICID]    pre_pc;

    wire is_hit = valid[pc[`ICID]] && tag[pc[`ICID]] == pc[`TGID];

    assign ins_flag_IF = ins_flag ? `True : cache_hit; 
    assign ins_IF = ins_flag ? ins : hit_ins;

    assign ins_flag_MC = !is_stall && !is_hit;
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
        pre_pc <= pc[`ICID];
        debug_now <= debug_now + 1;
        // $display("IC: ", debug_now);
        if (rst)
            debug_now <= 0;
        if (rst) begin
            valid <= 0;
            cache_hit <= `False;
        end
        else if (!rdy) begin
            
        end
        else begin
            if (is_hit && !is_stall) begin
                cache_hit <= !jp_wrong;
                hit_ins <= cache[pc[`ICID]];
            end
            else
                cache_hit <= `False;

            if (ins_flag) begin
                valid[pre_pc[`ICID]] <= `True;
                cache[pre_pc[`ICID]] <= ins;
                tag[pre_pc[`ICID]] <= pc[`TGID];
            end
        end
    end

endmodule