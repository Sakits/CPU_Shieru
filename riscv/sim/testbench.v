// testbench top module file
// for simulation only

`timescale 1ns/1ps
module testbench;

reg clk;
reg rst;

riscv_top #(.SIM(1)) top(
    .EXCLK(clk),
    .btnC(rst),
    .Tx(),
    .Rx(),
    .led()
);

reg [31: 0] now;
initial begin
  $dumpfile("cpu_run.vcd");
  $dumpvars;
  clk=0;
  rst=1;
  repeat(50) #1 clk=!clk;
  rst=0; 
  now = 0;
  repeat(1000) begin
    #1 clk = !clk;
    now = now + 1;
    $display(now);
  end
  // forever #1 clk=!clk;
  $display("finish");
  $finish;
end

endmodule