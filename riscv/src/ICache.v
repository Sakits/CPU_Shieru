`include "defines.v"

module ICache (
    input  wire             clk, rst, rdy, 
    input  wire             jp_wrong,                                   // 跳转错误

    // IF
    input  wire [31: 0]     pc, 
    output wire             ins_flag_IF, 
    output wire [31: 0]     ins_IF, 

    // MemCtrl
    input  wire             ins_flag, 
    input  wire [31: 0]     ins, 
    output wire             ins_flag_MC, 
    output wire [31: 0]     pc_MC
);

    reg  [`ICSZ]    valid;
    reg  [31: 0]    cache       [`ICSZ];
    reg             cache_hit;
    reg  [31: 0]    hit_ins;

    wire is_hit = valid[pc[`ICID]] && cache[pc[`ICID]][`TGID] == pc[`TGID];

    assign ins_flag_IF = ins_flag ? `True : cache_hit; 
    assign ins_IF = ins_flag ? ins : hit_ins;

    assign ins_flag_MC = !is_hit;
    assign pc_MC = pc;

    always @(posedge clk) begin
        if (rst) begin
            valid <= 0;
            cache_hit <= `False;
        end
        else if (!rdy) begin
            
        end
        else begin
            if (is_hit) begin
                cache_hit <= `True;
                hit_ins <= cache[pc[`ICID]];
            end
            else
                cache_hit <= `False;

            if (ins_flag) begin
                valid[ins[`ICID]] <= `True;
                cache[ins[`ICID]] <= ins;
            end
        end
    end

endmodule