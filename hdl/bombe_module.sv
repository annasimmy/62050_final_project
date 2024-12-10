module bombe_module 
  #(parameter CRIB_LEN=5) (
	input wire clk_in,
  input wire rst_in,
  input wire [4:0] coded_letter_in,
  input wire coded_valid_in,
  input wire message_done_in,
  input wire [CRIB_LEN-1:0][4:0] crib_in,
  output logic [8:0] rotor_select_out,
  output logic [14:0] rotor_initial_out,
  output logic rotor_valid_out
  );
  

  // Should only go from 0 to 12 - the extra x2 factors come from the for loop of 32 simultaneous Enigmas
  logic [3:0] rotor_1_initial; 
  logic [3:0] rotor_2_initial; 
  logic [3:0] rotor_3_initial; 
  // Should go 0 to 4
  logic [2:0] rotor_1_num;
  // rotor_2_num missing (4 possibilities) - again comes from the for loop
  // Should go 0 to 4
  logic [2:0] rotor_3_num; 

  // true if ith enigma is done checking current settings
  logic [31:0] ready_curr;
  logic [31:0] enigma_valid;
  logic [31:0][CRIB_LEN-1:0][4:0] enigma_output;
  logic [31:0][4:0] enigma_last_output;

  // Letter we are currently looking at in message
  logic [10:0] letter_pos;
  logic [4:0] coded_letter;
  logic writing;

  // High when rotor settings are valid
  logic rotor_valid;

  // Which of the 32 enigmas we are currently trying to output, if it is valid
  logic [5:0] output_num;

  logic done;

  
  xilinx_true_dual_port_read_first_2_clock_ram
      #(.RAM_WIDTH(5),
        .RAM_DEPTH(1024)) text_bram(
        // PORT A
        .addra(letter_pos),
        .dina(coded_letter_in), // we only use port A for reads!
        .clka(clk_in),
        .wea(coded_valid_in && writing), // read only
        .ena(1'b1),
        .rsta(rst_in),
        .regcea(1'b1),
        .douta(coded_letter),
        // PORT B
        .addrb(),
        .dinb(),
        .clkb(clk_in),
        .web(1'b1), // write always
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );

  genvar i;
  generate 
    for(i = 0; i < 32; i = i + 1) begin
      enigma curr_enigma
        (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rotor_select({
          rotor_1_num, 
          ((i[1:0] >= rotor_1_num) ? (i[1:0] == 3 : 3'b100 : {0, i[1:0] + 1}) : {0, i[1:0]}),
          rotor_3_num
        }),
        .rotor_initial({
          ((rotor_1_initial << 1) + i[2:2]),
          ((rotor_2_initial << 1) + i[3:3]),
          ((rotor_3_initial << 1) + i[4:4])
        }),
        .data_valid_in(&ready_curr),
        .rotor_valid_in(rotor_valid),
        .data_in(coded_letter),
        .ready(ready_curr[i]),
        .data_valid_out(enigma_valid[i]),
        .data_out(enigma_last_output[i])
        );
    end
  endgenerate


  always_ff @(posedge clk_in) begin
    if(rst_in) begin
      rotor_valid <= 0;
      rotor_1_initial <= 0;
      rotor_3_initial <= 0;
      rotor_3_num <= 0;
      rotor_1_num <= 0;
      output_num <= 0;
      rotor_valid <= 0;
      rotor_valid_out <= 0;
      done <= 0;
      letter_pos <= 0;
      writing <= 0;
    end else if(!done) begin
      if(!writing) begin
        if(message_done_in) begin
          writing <= 1;
          letter_pos <= 0;
        end else if(coded_valid_in) begin
          letter_pos <= letter_pos + 1;
        end
      end else if(&ready_curr && letter_pos == 1024) begin
        if(rotor_3_initial == 12) begin
          rotor_3_initial <= 0;
          if(rotor_2_initial == 12) begin
            rotor_2_initial <= 0;
            if(rotor_1_initial == 12) begin
              rotor_1_initial <= 0;
              if(rotor_3_num == 4) begin
                rotor_3_num <= 0;
                if(rotor_1_num == 4) begin
                  done <= 1;
                end else begin
                  rotor_1_num <= rotor_1_num + 1;
                end
              end else begin
                rotor_3_num <= rotor_3_num + 1;
              end

            end else begin
              rotor_1_initial <= rotor_1_initial + 1;
            end
          end else begin
            rotor_2_initial <= rotor_2_initial + 1;
          end
        end else begin
          rotor_3_initial <= rotor_3_initial + 1;
        end
        if(rotor_1_num != rotor_3_num) begin
          rotor_valid <= 1;
          letter_pos <= 0;
        end
      end else if(rotor_valid) begin
        rotor_valid <= 0;
      end else if(&ready_curr) begin
        if(output_num != 32) begin
          if(enigma_output[output_num][CRIB_LEN-1:0] == crib_in[CRIB_LEN-1:0]) begin
            rotor_initial_out <= {
                ((rotor_1_initial << 1) + output_num[2:2]),
                ((rotor_2_initial << 1) + output_num[3:3]),
                ((rotor_3_initial << 1) + output_num[4:4])
              };
            rotor_select_out <= {
                rotor_1_num, 
                ((output_num[1:0] >= rotor_1_num) ? (output_num[1:0] == 3 : 3'b100 : {0, output_num[1:0] + 1}) : {0, output_num[1:0]}),
                rotor_3_num
              };
            rotor_valid_out <= 1;
          end else begin
            rotor_valid_out <= 0;
          end
          enigma_output[output_num] <= {enigma_output[output_num][CRIB_LEN-2:0], 5'b00000};
          output_num <= output_num + 1;
        end else begin
          letter_pos <= letter_pos + 1;
          output_num <= 0;
          rotor_valid_out <= 0;
        end
      end else begin
        for(int i = 0; i < 32; i = i + 1) begin
          if(enigma_valid[i]) begin
            enigma_output[i] <= {enigma_output[i][CRIB_LEN-1:1], enigma_last_output[i]};
          end
        end
      end
    end
  end
endmodule