`include "defines.v"

module MemCtrl (
    input  wire             clk, rst, rdy, 
    input  wire             jp_wrong,                                   // 跳转错误

    // ICache
    input  wire             val_in_flag_IC, 
    input  wire [31: 0]     addr_IC, 
    output reg              val_out_flag_IC, 
    output reg  [31: 0]     val_out_IC, 

    // LSB
    input  wire             val_in_flag_LSB, 
    input  wire [31: 0]     val_in_LSB, 
    input  wire [ 2: 0]     insty_LSB, 
    input  wire [31: 0]     addr_LSB, 
    output reg              val_out_flag_LSB, 
    output reg  [31: 0]     val_out_LSB, 

    // RAM
    input  wire             io_buffer_full, 
    input  wire [ 7:0]      mem_din,	                            	// data input bus
    output reg  [ 7:0]      mem_dout,	                            	// data output bus
    output reg  [31:0]      mem_a,		                              	// address bus (only 17:0 is used)
    output reg              mem_wr 		                            	// write/read signal (1 for write)
);

    reg             last_is_read;
    reg  [ 1: 0]    step_LSB, step_IC;
    reg  [31: 0]    val_LSB, val_IC;
    wire            is_IO = addr_LSB[17:16] == 2'b11;

    always @(*) begin
        if (val_in_flag_LSB) begin
            mem_a = addr_LSB + step_LSB;
            if (!insty_LSB[2] || !insty_LSB[1:0] || (is_IO && last_is_read)) begin
                mem_dout = `null8;
                mem_wr = `False;
            end
            else begin
                case (step_LSB)
                    2'b00: mem_dout = val_in_LSB[ 7: 0];
                    2'b01: mem_dout = val_in_LSB[15: 8];
                    2'b11: mem_dout = val_in_LSB[23:16];
                    2'b10: mem_dout = val_in_LSB[31:24];
                endcase
                mem_wr = `True;
            end
        end
        else begin
            mem_a = addr_IC + step_IC;
            mem_dout = `null8;
            mem_wr = `False;
        end

        case (insty_LSB)
            `LB : val_out_LSB = {{24{mem_din[7]}}, mem_din};
            `LH : val_out_LSB = {{16{mem_din[7]}}, mem_din, val_LSB[7: 0]};
            `LW : val_out_LSB = {mem_din, val_LSB[23: 0]};
            `LBU: val_out_LSB = {24'b0, mem_din};
            `LHU: val_out_LSB = {16'b0, mem_din, val_LSB[7:0]};
            default: val_out_LSB = `null32;
        endcase

        val_out_IC = {mem_din, val_IC[23: 0]};
    end

    always @(posedge clk) begin
        if (rst) begin
            val_out_flag_IC <= `False;
            val_out_flag_LSB <= `False;
            mem_wr <= `False;
            last_is_read <= `False;
            step_LSB <= `null2;
            step_IC <= `null2;
        end 
        else if (!rdy) begin
            
        end if (jp_wrong && (!val_in_flag_LSB || !(insty_LSB == `SB || insty_LSB == `SH || insty_LSB == `SW))) begin
            val_out_flag_IC <= `False;
            val_out_flag_LSB <= `False;
            mem_wr <= `False;
            last_is_read <= `False;
            step_LSB <= `null2;
            step_IC <= `null2;
        end
        else begin
            if (val_in_flag_LSB) begin

                case (step_LSB)
                    2'b01: val_LSB[ 7: 0] <= mem_din;
                    2'b10: val_LSB[15: 8] <= mem_din;
                    2'b11: val_LSB[23:16] <= mem_din;
                endcase

                case (insty_LSB)
                    `LB: begin
                        val_out_flag_LSB <= `True;
                        last_is_read <= `True;
                    end 
                    `LH: begin
                        val_out_flag_LSB <= step_LSB[0] == 1'b1;
                        last_is_read <= `True;
                        step_LSB[0] <= -(~step_LSB[0]);
                    end
                    `LW: begin
                        val_out_flag_LSB <= step_LSB == 2'b11;
                        last_is_read <= `True;
                        step_LSB <= -(~step_LSB);
                    end
                    `LBU: begin
                        val_out_flag_LSB <= `True;
                        last_is_read <= `True;
                    end
                    `LHU: begin
                        val_out_flag_LSB <= step_LSB[0] == 1'b1;
                        last_is_read <= `True;
                        step_LSB[0] <= -(~step_LSB[0]);
                    end
                    `SB: begin
                        val_out_flag_LSB <= !(last_is_read && is_IO);
                        last_is_read <= `False;
                    end
                    `SH: begin
                        val_out_flag_LSB <= step_LSB[0] == 1'b1;
                        last_is_read <= `False;
                        if (!(last_is_read && is_IO))
                            step_LSB[0] <= -(~step_LSB[0]);
                    end
                    `SW: begin
                        val_out_flag_LSB <= step_LSB == 2'b11;
                        last_is_read <= `False;
                        if (!(last_is_read && is_IO))
                            step_LSB <= -(~step_LSB);
                    end
                endcase
            end
            else if (val_in_flag_IC) begin
                case (step_IC)
                    2'b01: val_IC[ 7: 0] <= mem_din;
                    2'b10: val_IC[15: 8] <= mem_din;
                    2'b11: val_IC[23:16] <= mem_din;
                endcase

                val_out_flag_IC <= step_IC == 2'b11;
                last_is_read <= `True;
                step_IC <= -(~step_IC);
            end
            else
                last_is_read <= `False;
        end 
    end
    
endmodule