module data_module (
	input wire clk_in,
  input wire rst_in,
  input wire letter_valid_in,
  input wire rotor_valid_in,
  input wire [15:0] sw,
  output logic rotor_valid_out,
  output logic letter_valid_out,
  output logic [8:0] rotor_select_out,
  output logic [14:0] rotor_initial_out,
  output logic [4:0] char_out);

  logic prev_letter_valid;
  logic prev_rotor_valid;

  always_ff @(posedge clk_in) begin
    if(rst_in) begin
      rotor_valid_out <= 0;
      letter_valid_out <= 0;
      rotor_select_out <= 0;
      rotor_initial_out <= 0;
      char_out <= 0;
      prev_letter_valid <= 0;
      prev_rotor_valid <= 0;
    end else begin
      if(rotor_valid_out) begin
        rotor_valid_out <= 0;
      end
      if(letter_valid_out) begin
        letter_valid_out <= 0;
      end
      if(rotor_valid_in && !prev_rotor_valid) begin
        if(sw[15:15] == 1'b0) begin
          // Setting the initial rotor rotations
          rotor_initial_out <= sw[14:0];
        end else if(sw[15:14] == 2'b10) begin
          // Setting the rotor selections
          rotor_select_out <= sw[8:0];
          if(!rotor_valid_out) begin
            rotor_valid_out <= 1;
          end
        end 
      end
      if (letter_valid_in && !prev_letter_valid) begin
          // Setting the character to send (after doing initial rotor setup)
          char_out <= sw[4:0];
          if(!letter_valid_out) begin
            letter_valid_out <= 1;
          end
      end
      prev_letter_valid <= letter_valid_in;
      prev_rotor_valid <= rotor_valid_in;
    end
  end
endmodule