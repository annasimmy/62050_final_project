module bombe_module (
	input wire clk_in,
  input wire rst_in,
  input [4:0] coded_letter,
  input [4:0] crib_in [15:0],
  output [8:0] rotor_select_out,
  output [14:0] rotor_initial_out,
  output rotor_valid_out
  );

  // Todo: Better way of passing in coded message (BRAM)
  logic [4:0] coded_message [1023:0];

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
  logic [31:0] checked_curr;
  logic [31:0] ready_curr;

  logic [4:0] enigma_valid [31:0];
  logic [4:0] enigma_output [31:0];

  // Letter we are currently looking at in message
  logic [9:0] letter_pos;

  // High when rotor settings are valid
  logic rotor_valid;

  genvar i;
  generate 
    for(i = 0; i < 32; i = i + 1) begin
      enigma curr_enigma
        (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rotor_select({
          rotor_1_num, 
          ((i[1:0] >= rotor_1_num) ? (i[1:0] == 3 : 3'b100 : {0, i[1:0]}) : {0, i[1:0]}),
          rotor_3_num
        }),
        .rotor_initial({
          ((rotor_1_initial << 1) + i[2:2]),
          ((rotor_2_initial << 1) + i[3:3]),
          ((rotor_3_initial << 1) + i[4:4])
        }),
        .data_valid_in(&ready_curr),
        .rotor_valid_in(rotor_valid),
        .data_in(coded_message[letter_pos]),
        .ready(ready_curr[i]),
        .data_valid_out(enigma_valid[i]),
        .data_out(enigma_output[i])
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
    end else if(&ready_curr && letter_pos == 1023) begin
      if(rotor_3_initial == 12) begin
        rotor_3_initial <= 0;
        if(rotor_2_initial == 12) begin
          rotor_2_initial <= 0;
          if(rotor_1_initial == 12) begin
            rotor_1_initial <= 0;
            if(rotor_3_num == 4) begin
              rotor_3_num <= 0;
              if(rotor_1_num == 4) begin
                // TODO: Bombe is done running, end
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
        for(int i = 0; i < 32; i = i + 1) begin
          checked_curr[i] <= 0;
        end
        rotor_valid <= 1;
      end
    end else if(rotor_valid) begin
      rotor_valid <= 0;
    end
    end else if(&ready_curr) begin
      // Todo: Check if the last 16 outputs of enigma_output[i] match the crib, if so then output it as a valid rotor setting
      // Else do nothing
      letter_pos <= letter_pos + 1;
    end
  end
endmodule