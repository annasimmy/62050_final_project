`default_nettype none

module enigma
    (input wire clk_in,
     input wire rst_in,
     input wire [8:0] rotor_select,
     input wire [14:0] rotor_initial,
     input wire data_valid_in,
     input wire [4:0] data_in,
	 output logic data_valid_out,
     output logic [4:0] data_out);

    //Rotor mappings
    logic [4:0] rotor_1 [25:0] = {23,20,15,11,1,19,21,25,22,18,2,24,10,8,17,3,16,26,5,6,13,4,9,14,12,7};
    logic [4:0] rotor_2 [25:0] = {7,10,12,16,21,2,19,23,5,13,3,20,17,22,8,24,1,15,6,26,4,18,11,25,14,9};
    logic [4:0] rotor_3 [25:0] = {10,23,6,13,8,14,2,16,21,19,4,25,20,9,24,22,26,7,18,17,12,1,15,5,11,3};
    logic [4:0] rotor_4 [25:0] = {6,7,26,10,13,22,24,5,16,2,23,19,8,17,20,12,9,21,4,25,11,3,14,18,1,15};
    logic [4:0] rotor_5 [25:0] = {8,5,10,24,17,15,20,26,2,22,6,4,1,19,3,9,12,23,16,7,25,14,13,21,18,11};

    //Reflector
    logic [4:0] reflector [25:0] = {13,15,23,10,25,16,21,24,14,4,19,18,1,9,2,6,22,12,11,26,7,17,3,8,5,20};

    //Rotor FIFOs
    logic [4:0] rotor_i_fifo [25:0];
    logic [4:0] rotor_ii_fifo [25:0];
    logic [4:0] rotor_iii_fifo [25:0];
    
    //Moving reflectors
    logic [4:0] rotor_i [25:0];
    logic [4:0] rotor_ii [25:0];
    logic [4:0] rotor_iii [25:0];

    //Encoding stages
    logic [4:0] data_pipeline [6:0];

    //Counters
    logic [4:0] first_rotor_counter;
    logic [4:0] second_rotor_counter;
    
    always_ff @(posedge clk_in) begin
	if (rst_in) begin
	    first_rotor_counter <= 0;
	    second_rotor_counter <= 0;
	    //Set rotor_i to correct rotor
	    case (rotor_select[8:6])
		1 : rotor_i_fifo <= rotor_1;
		2 : rotor_i_fifo <= rotor_2;
		3 : rotor_i_fifo <= rotor_3;
		4 : rotor_i_fifo <= rotor_4;
		5 : rotor_i_fifo <= rotor_5;
		default : rotor_i_fifo <= rotor_1;
	    endcase
	    //Set rotor_ii to correct rotor
	    case (rotor_select[5:3])
                1 : rotor_ii_fifo <= rotor_1;
                2 : rotor_ii_fifo <= rotor_2;
                3 : rotor_ii_fifo <= rotor_3;
                4 : rotor_ii_fifo <= rotor_4;
                5 : rotor_ii_fifo <= rotor_5;
                default : rotor_ii_fifo <= rotor_2;
            endcase
	    //Set rotor_iii to correct rotor
	    case (rotor_select[2:0])
                1 : rotor_iii_fifo <= rotor_1;
                2 : rotor_iii_fifo <= rotor_2;
                3 : rotor_iii_fifo <= rotor_3;
                4 : rotor_iii_fifo <= rotor_4;
                5 : rotor_iii_fifo <= rotor_5;
                default : rotor_iii_fifo <= rotor_3;
            endcase
	    //Shift rotors to correct initial positions
	    for (int k=0; k<26; k=k+1) begin
		//Shifting rotor_i
		if (rotor_initial[14:10]+k < 26) begin
		    rotor_i[k] <= rotor_i_fifo[rotor_initial[14:10]+k];
		end else begin
		    rotor_i[k] <= rotor_i_fifo[rotor_initial[14:10]+k-26];
		end 
		//Shifting rotor_ii
		if (rotor_initial[9:5]+k < 26) begin
                    rotor_ii[k] <= rotor_ii_fifo[rotor_initial[9:5]+k];
                end else begin
                    rotor_ii[k] <= rotor_ii_fifo[rotor_initial[9:5]+k-26];
                end 
		//Shifting rotor_iii
		if (rotor_initial[4:0]+k < 26) begin
                    rotor_iii[k] <= rotor_iii_fifo[rotor_initial[4:0]+k];
                end else begin
                    rotor_iii[k] <= rotor_iii_fifo[rotor_initial[4:0]+k-26];
                end 
	    end
	end else if (data_valid_in) begin
	//Rotor movement
	    //Counters
	    first_rotor_counter <= (first_rotor_counter == 26)? 0: first_rotor_counter + 1;
	    second_rotor_counter <= ((second_rotor_counter == 26) && (first_rotor_counter == 26))? 0 : (first_rotor_counter == 26)? second_rotor_counter + 1: second_rotor_counter;
	    //First Rotor movement
	    for (int k=0; k<25; k=k+1) begin
		rotor_i[k+1] <= rotor_i[k];
	    end 
	    rotor_i[0] <= rotor_i[25];
	    //Second Rotor movement
	    if (first_rotor_counter == 26) begin
		for (int k=0; k<25; k=k+1) begin
		    rotor_ii[k+1] <= rotor_ii[k];
	        end
		rotor_ii[0] <= rotor_ii[25];
	    end
	    //Third Rotor Movement
	    if (second_rotor_counter == 26) begin
                for (int k=0; k<25; k=k+1) begin
                    rotor_iii[k+1] <= rotor_iii[k];
                end 
                rotor_iii[0] <= rotor_iii[25];
            end 
	//Data movement
	    data_pipeline[0] <= rotor_i[data_in];
	    data_pipeline[1] <= rotor_ii[data_pipeline[0]];
	    data_pipeline[2] <= rotor_iii[data_pipeline[1]];
	    data_pipeline[3] <= reflector[data_pipeline[2]];
	    data_pipeline[4] <= rotor_iii[data_pipeline[3]];
	    data_pipeline[5] <= rotor_ii[data_pipeline[4]];
	    data_pipeline[6] <= rotor_ii[data_pipeline[5]];
	    data_out <= rotor_i[data_pipeline[6]];
	end
    end

endmodule

`default_nettype wire
