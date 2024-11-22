module pwm(   input wire clk_in,
              input wire rst_in,
              input wire [11:0] dc_in,
              output logic sig_out);
 
    logic [31:0] count;
    evt_counter #(.MAX_COUNT(2559)) mc 
                (.clk_in(clk_in),
                .rst_in(rst_in),
                .evt_in(1),
                .count_out(count));
    assign sig_out = count<dc_in; //very simple threshold check
endmodule