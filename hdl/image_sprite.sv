`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */

module image_sprite #(
  parameter WIDTH=256, HEIGHT=512) (
  input wire pixel_clk_in,
  input wire rst_in,
  input wire [10:0] x_in, hcount_in,
  input wire [9:0]  y_in, vcount_in,
  input wire [4:0] letter,
  output logic [7:0] red_out,
  output logic [7:0] green_out,
  output logic [7:0] blue_out
  );

  logic [3:0] letter_y_pos;
  logic [3:0] letter_x_pos;

  always_comb begin
    if(letter < 6) begin
      letter_y_pos = 0;
    end else if(letter < 12) begin
      letter_y_pos = 1;
    end else if(letter < 18) begin
      letter_y_pos = 2;
    end else if(letter < 24) begin
      letter_y_pos = 3;
    end else begin
      letter_y_pos = 4;
    end
    letter_x_pos = letter - 6 * letter_y_pos;
  end

  // calculate rom address
  logic [$clog2(WIDTH*HEIGHT)-1:0] image_addr;
  assign image_addr = (hcount_in - x_in + 38 * letter_x_pos) + ((vcount_in - y_in + 45 * letter_y_pos) * WIDTH);

  logic in_sprite;
  assign in_sprite = ((hcount_in >= x_in && hcount_in < (x_in + 38)) &&
                      (vcount_in >= y_in && vcount_in < (y_in + 45)));   
  logic in_sprite2;
  logic in_sprite3;
  logic in_sprite4;
  logic in_sprite5;
  always_ff @(posedge pixel_clk_in) begin
    in_sprite2 <= in_sprite;
    in_sprite3 <= in_sprite2;
    in_sprite4 <= in_sprite3;
    in_sprite5 <= in_sprite4;
  end

  logic [7:0] pixel_num;
  logic [23:0] pixel_col;
  
  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(8),                       // Specify RAM data width
    .RAM_DEPTH(WIDTH*HEIGHT),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(`FPATH(image.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) brom1 (
    .addra(image_addr),     // Address bus, width determined from RAM_DEPTH
    .dina(0),       // RAM input data, width determined from RAM_WIDTH
    .clka(pixel_clk_in),       // Clock
    .wea(0),         // Write enable
    .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst_in),       // Output reset (does not affect memory contents)
    .regcea(1),   // Output register enable
    .douta(pixel_num)      // RAM output data, width determined from RAM_WIDTH
  );

  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(24),                       // Specify RAM data width
    .RAM_DEPTH(256),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(`FPATH(palette.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) brrom2 (
    .addra(pixel_num),     // Address bus, width determined from RAM_DEPTH
    .dina(0),       // RAM input data, width determined from RAM_WIDTH
    .clka(pixel_clk_in),       // Clock
    .wea(0),         // Write enable
    .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst_in),       // Output reset (does not affect memory contents)
    .regcea(1),   // Output register enable
    .douta(pixel_col)      // RAM output data, width determined from RAM_WIDTH
  );

  // Modify the module below to use your BRAMs!
  assign red_out =    (letter >= 26 || !in_sprite5) ? 255 : pixel_col[23:16];
  assign green_out =  (letter >= 26 || !in_sprite5) ? 255 : pixel_col[15:8];
  assign blue_out =   (letter >= 26 || !in_sprite5) ? 255 : pixel_col[7:0];
endmodule
