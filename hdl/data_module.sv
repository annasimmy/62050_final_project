module data_module (
	input wire clk_in,
  input wire rst_in,
  input wire ready_in,
  input wire data_valid_in,
  input wire [15:0] sw,
  output logic rotor_valid_out,
  output logic letter_valid_out,
  output logic [8:0] rotor_select_out,
  output logic [14:0] rotor_initial_out,
  output logic [4:0] char_out);

  logic prev_data_valid;

  always_ff @(posedge clk_in) begin
    if(rst_in) begin
      rotor_valid_out <= 0;
      letter_valid_out <= 0;
      rotor_select_out <= 0;
      rotor_initial_out <= 0;
      char_out <= 0;
      prev_data_valid <= 0;
    end else begin
      if(rotor_valid_out) begin
        rotor_valid_out <= 0;
      end
      if(letter_valid_out) begin
        letter_valid_out <= 0;
      end
      if(data_valid_in && !prev_data_valid) begin
        if(sw[15:15] == 1'b0) begin
          rotor_initial_out <= sw[14:0];
        end else if(sw[15:14] == 2'b10) begin
          rotor_select_out <= sw[8:0];
          if(ready_in && !rotor_valid_out) begin
            rotor_valid_out <= 1;
          end
        end else begin 
          char_out <= sw[4:0];
          if(ready_in && !letter_valid_out) begin
            letter_valid_out <= 1;
          end
        end
      end
      prev_data_valid <= data_valid_in;
    end
  end
endmodule