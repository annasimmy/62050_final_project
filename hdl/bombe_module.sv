module bombe_module (
	input wire clk_in,
  input wire rst_in
  // Todo: Input/output needs fixing
  );

  
  logic [4:0] coded_message [1023:0];

  // Should only go from 0 to 12 - the extra x2 factors come from the for loop of 32 simultaneous Enigmas
  logic [3:0] rotor_1_initial; 
  logic [3:0] rotor_2_initial; 
  logic [3:0] rotor_3_initial; 
  // Should go 0 to 4
  logic [2:0] rotor_1_num;
  // rotor_2_num missing (4 possibilities) - again comes from the for loop
  // Should go 0 to 4
  logic [1:0] rotor_3_num; 

  // true if ith enigma is done checking current settings
  logic checked_curr [31:0];

  logic [4:0] enigma_output [31:0];

  // Letter we are currently looking at in message
  logic [9:0] letter_pos;

  always_ff @(posedge clk_in) begin
    if(rst_in) begin
      
    end else if(~(|checked_curr)) begin
      if(rotor_3_initial == 12) begin
        rotor_3_initial <= 0;
        if(rotor_2_initial == 12) begin
          rotor_2_initial <= 0;
          if(rotor_1_initial == 12) begin
            rotor_1_initial <= 0;
            
            // Todo 
            // if(rotor_3_num == 2) begin
            //   rotor_3_initial <= 0;
            // end else begin
            //   rotor_3_initial <= rotor_3_initial + 1;
            // end

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
      end
    end else begin
      for(int i = 0; i < 32; i = i + 1) begin
        enigma curr_enigma
          (
          .clk_in(clk_in),
          .rst_in(rst_in),
          .rotor_select({
            rotor_1_num, 
            // Todo: Needs fixing
            (i[1:0] >= rotor_1_num ? : (logic[2:0]'i[1:0]) + 1 : (logic[2:0]'i[1:0])),
            rotor_3_num,
          }),
          .rotor_initial({
            (rotor_1_initial << 1) + i[2:2],
            (rotor_2_initial << 1) + i[3:3],
            (rotor_3_initial << 1) + i[4:4],
          }),
          .data_valid_in(),
          .data_in(),
          .data_out(enigma_output[i])
          );
        // Todo: Add output == input in this if statement
        if(enigma_output[i] != coded_message[i]) begin
          checked_curr[i] <= 1;
        end
      end

    
    end
  end
endmodule