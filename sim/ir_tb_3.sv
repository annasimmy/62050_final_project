`timescale 1ns / 1ps
`default_nettype none

module ir_tb();

  logic clk_in;
  logic rst_in;
  logic signal_in;
  logic [31:0] code_out;
  logic new_code_out;
  logic [2:0] error_out;
  logic [3:0] state_out;

  logic [31:0] message = 'hABCD1234;
  int dur;
  logic bit_to_send;

  parameter SBD  = 900; //sync burst duration
  parameter SSD  = 450; //sync silence duration
  parameter BBD = 60; //bit burst duration
  parameter BSD0 = 60; //bit silence duration (for 0)
  parameter BSD1 = 160; //bit silence duration (for 1)
  parameter MARGIN = 20; //The +/- of your signals
  ir_decoder
       #(.SBD(SBD),
         .SSD(SSD),
         .BBD(BBD),
         .BSD0(BSD0),
         .BSD1(BSD1),
         .MARGIN(MARGIN)
        ) uut
        ( .clk_in(clk_in),
          .rst_in(rst_in),
          .signal_in(signal_in),
          .code_out(code_out),
          .new_code_out(new_code_out),
          .error_out(error_out),
          .state_out(state_out)
        );

  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_in = !clk_in;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("ir_3.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,ir_tb);
    $display("Starting Sim"); //print nice message at start
    clk_in = 0;
    rst_in = 0;
    signal_in =1;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    $display("Interrupted Message:");
    signal_in = 0;
    dur = $signed(SBD); //+$random(seed)%(MARGIN-1);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in=1;
    dur = $signed(SSD);// + $random(seed)%(MARGIN-1);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    for (int j=0; j<20; j = j+1)begin
      signal_in=0;
      dur = $signed(BBD);// +$random(seed)%(MARGIN-1);
      for (int i=0; i < dur; i=i+1)begin
        #10;
      end
      if (message[31])begin
        dur = $signed(BSD1);// +$random(seed)%(MARGIN-1);
      end else begin
        dur = $signed(BSD0);// +$random(seed)%(MARGIN-1);
      end
      signal_in=1;
      for (int i=0; i < dur; i=i+1)begin
        #10;
      end
      message = {message[30:0],1'b0};
    end
    //final dip
    signal_in=0;
    dur = $signed(BBD);// +$random(seed)%(MARGIN-1);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in = 1;
    #500;
    $display("Busted Sync 1");
    message = 'h19861989;
    signal_in = 0;
    dur = $signed(SBD);// +$random(seed)%(MARGIN-1);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in=1;
    dur = $signed(SSD);// + $random(seed)%(MARGIN-1);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in = 1;
    #500;
    $display("Busted Sync 2");
    message = 'h19861989;
    signal_in = 0;
    dur = $signed(SBD)*2;
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in=1;
    dur = $signed(SSD);// + $random(seed)%(MARGIN-1);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in = 1;
    #500;
    $display("Busted Sync 3");
    message = 'h19861989;
    signal_in = 0;
    dur = $signed(SBD);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in=1;
    dur = $signed(SSD)*0.2;
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in = 0;
    #100;
    signal_in = 1;
    #500;
    $display("Bad Ones");
    message = 'h19861989;
    signal_in = 0;
    dur = $signed(SBD);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in=1;
    dur = $signed(SSD);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    for (int j=0; j<32; j = j+1)begin
      signal_in=0;
      dur = $signed(BBD);
      for (int i=0; i < dur; i=i+1)begin
        #10;
      end
      if (message[31])begin
        dur = $signed(BSD0)>>1;//should be BSD1!
      end else begin
        dur = $signed(BSD0);
      end
      signal_in=1;
      for (int i=0; i < dur; i=i+1)begin
        #10;
      end
      message = {message[30:0],1'b0};
    end
    //final dip
    signal_in=0;
    dur = $signed(BBD);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in = 1;
    #500;
    $display("Good Packet");
    message = 'h19861989;
    signal_in = 0;
    dur = $signed(SBD);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in=1;
    dur = $signed(SSD);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    for (int j=0; j<32; j = j+1)begin
      signal_in=0;
      dur = $signed(BBD);
      for (int i=0; i < dur; i=i+1)begin
        #10;
      end
      if (message[31])begin
        dur = $signed(BSD1);//should be BSD1!
      end else begin
        dur = $signed(BSD0);
      end
      signal_in=1;
      for (int i=0; i < dur; i=i+1)begin
        #10;
      end
      message = {message[30:0],1'b0};
    end
    //final dip
    signal_in=0;
    dur = $signed(BBD);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in = 1;
    #1500;
    $display("Simulation finished");
    $finish;
  end
endmodule
`default_nettype wire