`default_nettype none

module enigma
    (input wire clk_in,
     input wire rst_in,
     input wire [8:0] rotor_select,
     input wire [14:0] rotor_initial,
     input wire data_valid_in,
     input wire rotor_valid_in,
     input wire [4:0] data_in,
     output logic ready,
     output logic data_valid_out,
     output logic [4:0] data_out);

    //Rotor mappings
    logic [25:0][4:0] rotor_1 = {5'd23,5'd20,5'd15,5'd11,5'd1,5'd19,5'd21,5'd25,5'd22,5'd18,5'd2,5'd24,5'd10,5'd8,5'd17,5'd3,5'd16,5'd26,5'd5,5'd6,5'd13,5'd4,5'd9,5'd14,5'd12,5'd7};
    logic [25:0][4:0] rotor_2 = {5'd7,5'd10,5'd12,5'd16,5'd21,5'd2,5'd19,5'd23,5'd5,5'd13,5'd3,5'd20,5'd17,5'd22,5'd8,5'd24,5'd1,5'd15,5'd6,5'd26,5'd4,5'd18,5'd11,5'd25,5'd14,5'd9};
    logic [25:0][4:0] rotor_3 = {5'd10,5'd23,5'd6,5'd13,5'd8,5'd14,5'd2,5'd16,5'd21,5'd19,5'd4,5'd25,5'd20,5'd9,5'd24,5'd22,5'd26,5'd7,5'd18,5'd17,5'd12,5'd1,5'd15,5'd5,5'd11,5'd3};
    logic [25:0][4:0] rotor_4 = {5'd6,5'd7,5'd26,5'd10,5'd13,5'd22,5'd24,5'd5,5'd16,5'd2,5'd23,5'd19,5'd8,5'd17,5'd20,5'd12,5'd9,5'd21,5'd4,5'd25,5'd11,5'd3,5'd14,5'd18,5'd1,5'd15};
    logic [25:0][4:0] rotor_5 = {5'd8,5'd5,5'd10,5'd24,5'd17,5'd15,5'd20,5'd26,5'd2,5'd22,5'd6,5'd4,5'd1,5'd19,5'd3,5'd9,5'd12,5'd23,5'd16,5'd7,5'd25,5'd14,5'd13,5'd21,5'd18,5'd11};

    //Rotor Backwards Mapping
    logic [25:0][4:0] backwards_rotor_1 = {5'd5,5'd11,5'd16,5'd22,5'd19,5'd20,5'd26,5'd14,5'd23,5'd13,5'd4,5'd25,5'd21,5'd24,5'd3,5'd17,5'd15,5'd10,5'd6,5'd2,5'd7,5'd9,5'd1,5'd12,5'd8,5'd18};
    logic [25:0][4:0] backwards_rotor_2 = {5'd17,5'd6,5'd11,5'd21,5'd9,5'd19,5'd1,5'd15,5'd26,5'd2,5'd23,5'd3,5'd10,5'd25,5'd18,5'd4,5'd13,5'd22,5'd7,5'd12,5'd5,5'd14,5'd8,5'd16,5'd24,5'd20};
    logic [25:0][4:0] backwards_rotor_3 = {5'd22,5'd7,5'd26,5'd11,5'd24,5'd3,5'd18,5'd5,5'd14,5'd1,5'd25,5'd21,5'd4,5'd6,5'd23,5'd8,5'd20,5'd19,5'd10,5'd13,5'd9,5'd16,5'd2,5'd15,5'd12,5'd17};
    logic [25:0][4:0] backwards_rotor_4 = {5'd25,5'd10,5'd22,5'd19,5'd8,5'd1,5'd2,5'd13,5'd17,5'd4,5'd21,5'd16,5'd5,5'd23,5'd26,5'd9,5'd14,5'd24,5'd12,5'd15,5'd18,5'd6,5'd11,5'd7,5'd20,5'd3};
    logic [25:0][4:0] backwards_rotor_5 = {5'd13,5'd9,5'd15,5'd12,5'd2,5'd11,5'd20,5'd1,5'd16,5'd3,5'd26,5'd17,5'd23,5'd22,5'd6,5'd19,5'd5,5'd25,5'd14,5'd7,5'd24,5'd10,5'd18,5'd4,5'd21,5'd8};

    //Refelctor
    logic [25:0][4:0] reflector = {5'd13,5'd15,5'd23,5'd10,5'd25,5'd16,5'd21,5'd24,5'd14,5'd4,5'd19,5'd18,5'd1,5'd9,5'd2,5'd6,5'd22,5'd12,5'd11,5'd26,5'd7,5'd17,5'd3,5'd8,5'd5,5'd20};

    //Rotor FIFOs
    logic [25:0][4:0] rotor_i_fifo;
    logic [25:0][4:0] rotor_ii_fifo;
    logic [25:0][4:0] rotor_iii_fifo;

    //Backwards Rotor FIFOs
    logic [25:0][4:0] backwards_rotor_i_fifo;
    logic [25:0][4:0] backwards_rotor_ii_fifo;
    logic [25:0][4:0] backwards_rotor_iii_fifo;
    
    //Moving Rotors
    logic [4:0] rotor_i [25:0];
    logic [4:0] rotor_ii [25:0];
    logic [4:0] rotor_iii [25:0];

    //Moving Backwards Rotors
    logic [4:0] backwards_rotor_i [25:0];
    logic [4:0] backwards_rotor_ii [25:0];
    logic [4:0] backwards_rotor_iii [25:0];

    //Encoding stages
    logic [4:0] data_pipeline [5:0];

    //Data Valid Out 
    logic data_valid_out_pipeline [5:0];

    //Counters
    logic [4:0] first_rotor_counter;
    logic [4:0] second_rotor_counter;
    
    always_ff @(posedge clk_in) begin
	if (rst_in) begin
	    ready <= 1'b1;
	    data_valid_out_pipeline[0] <= 0;
	    data_valid_out_pipeline[1] <= 0;
	    data_valid_out_pipeline[2] <= 0;
	    data_valid_out_pipeline[3] <= 0;
    	    data_valid_out_pipeline[4] <= 0;
	    data_valid_out_pipeline[5] <= 0;
	    data_valid_out_pipeline[6] <= 0;
	end else if (rotor_valid_in) begin
	    ready <= 1'b1;
	    first_rotor_counter <= 0;
	    second_rotor_counter <= 0;
	    data_valid_out_pipeline[0] <= 0;
            data_valid_out_pipeline[1] <= 0;
            data_valid_out_pipeline[2] <= 0;
            data_valid_out_pipeline[3] <= 0;
            data_valid_out_pipeline[4] <= 0;
            data_valid_out_pipeline[5] <= 0;
            data_valid_out_pipeline[6] <= 0;
	    //Set rotor_i to correct rotor
	    case (rotor_select[8:6])
		1 : begin 
			rotor_i_fifo <= rotor_1;
			backwards_rotor_i_fifo <= backwards_rotor_1;
		    end
		2 : begin
			rotor_i_fifo <= rotor_2;
			backwards_rotor_i_fifo <= backwards_rotor_2;
		    end
		3 : begin 
			rotor_i_fifo <= rotor_3;
			backwards_rotor_i_fifo <= backwards_rotor_3;
		    end
		4 : begin
			rotor_i_fifo <= rotor_4;
			backwards_rotor_i_fifo <= backwards_rotor_4;
		    end
		5 : begin
			rotor_i_fifo <= rotor_5;
			backwards_rotor_i_fifo <= backwards_rotor_5;
		    end
		default : begin
				rotor_i_fifo <= rotor_1;
				backwards_rotor_i_fifo <= backwards_rotor_1;
			  end
	    endcase
	    //Set rotor_ii to correct rotor
	    case (rotor_select[5:3])
                1 : begin
			rotor_ii_fifo <= rotor_1;
			backwards_rotor_ii_fifo <= backwards_rotor_1;
		    end
                2 : begin
			rotor_ii_fifo <= rotor_2;
			backwards_rotor_ii_fifo <= backwards_rotor_2;
		    end
                3 : begin
			rotor_ii_fifo <= rotor_3;
			backwards_rotor_ii_fifo <= backwards_rotor_3;
		    end
                4 : begin
			rotor_ii_fifo <= rotor_4;
			backwards_rotor_ii_fifo <= backwards_rotor_4;
		    end
                5 : begin
			rotor_ii_fifo <= rotor_5;
			backwards_rotor_ii_fifo <= backwards_rotor_5;
		    end
                default : begin
				rotor_ii_fifo <= rotor_2;
				backwards_rotor_ii_fifo <= backwards_rotor_2;
			  end
            endcase
	    //Set rotor_iii to correct rotor
	    case (rotor_select[2:0])
                1 : begin
			rotor_iii_fifo <= rotor_1;
			backwards_rotor_iii_fifo <= backwards_rotor_1;
		    end
                2 : begin
			rotor_iii_fifo <= rotor_2;
		        backwards_rotor_iii_fifo <= backwards_rotor_2;
		    end
                3 : begin
			rotor_iii_fifo <= rotor_3;
			backwards_rotor_iii_fifo <= backwards_rotor_3;
		    end
                4 : begin
			rotor_iii_fifo <= rotor_4;
			backwards_rotor_iii_fifo <= backwards_rotor_4;
		    end
                5 : begin
			rotor_iii_fifo <= rotor_5;
			backwards_rotor_iii_fifo <= backwards_rotor_5;
		    end
                default : begin
				rotor_iii_fifo <= rotor_3;
			  	backwards_rotor_iii_fifo <= backwards_rotor_3;
			  end
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
		//Shifting backwards_rotor_i
		if (backwards_rotor_i_fifo[k]+rotor_initial[14:10] < 27) begin
		    backwards_rotor_i[k] <= backwards_rotor_i_fifo[k]+rotor_initial[14:10];
		end else begin
		    backwards_rotor_i[k] <= backwards_rotor_i_fifo[k]+rotor_initial[14:10]-26;
		end
		//Shifting backwards_rotor_ii
                if (backwards_rotor_ii_fifo[k]+rotor_initial[9:5] < 27) begin
                    backwards_rotor_ii[k] <= backwards_rotor_ii_fifo[k]+rotor_initial[9:5];
                end else begin
                    backwards_rotor_ii[k] <= backwards_rotor_ii_fifo[k]+rotor_initial[9:5]-26;
                end 
		//Shifting backwards_rotor_iii
                if (backwards_rotor_iii_fifo[k]+rotor_initial[4:0] < 27) begin
                    backwards_rotor_iii[k] <= backwards_rotor_iii_fifo[k]+rotor_initial[4:0];
                end else begin
                    backwards_rotor_iii[k] <= backwards_rotor_iii_fifo[k]+rotor_initial[4:0]-26;
                end 
	    end
	end else if (data_valid_in && ready) begin
	//Data Movement
	    ready <= 0;
	    data_pipeline[0] <= rotor_i[26-data_in];
	    data_valid_out_pipeline[0] <= 1'b1;
	end else if (data_valid_out_pipeline[5]) begin
	//Rotor movement
            //Counters
	    data_valid_out_pipeline[0] <= 0;
            first_rotor_counter <= (first_rotor_counter == 25)? 0: first_rotor_counter + 1;
            second_rotor_counter <= ((second_rotor_counter == 25) && (first_rotor_counter == 25))? 0 : (first_rotor_counter == 25)? second_rotor_counter + 1: second_rotor_counter;
            //First Rotor movement
            for (int k=0; k<25; k=k+1) begin
                rotor_i[k+1] <= rotor_i[k];
            end 
            rotor_i[0] <= rotor_i[25];
            for (int i=0; i<26; i=i+1) begin
                if (backwards_rotor_i[i] > 1) begin
                    backwards_rotor_i[i] <= backwards_rotor_i[i] - 1;
                end else begin
                    backwards_rotor_i[i] <= 5'd26;
                end 
            end 
            //Second Rotor movement
            if (first_rotor_counter == 25) begin
                for (int k=0; k<25; k=k+1) begin
                    rotor_ii[k+1] <= rotor_ii[k];
                end 
                rotor_ii[0] <= rotor_ii[25];
                for (int i=0; i<26; i=i+1) begin
                    if (backwards_rotor_ii[i] > 1) begin
                        backwards_rotor_ii[i] <= backwards_rotor_ii[i] - 1;
                    end else begin
                        backwards_rotor_ii[i] <= 5'd26;
                    end 
                end 
            end 
            //Third Rotor Movement
            if (second_rotor_counter == 25) begin
                for (int k=0; k<25; k=k+1) begin
                    rotor_iii[k+1] <= rotor_iii[k];
                end 
                rotor_iii[0] <= rotor_iii[25];
                for (int i=0; i<26; i=i+1) begin
                    if (backwards_rotor_iii[i] > 1) begin
                        backwards_rotor_iii[i] <= backwards_rotor_iii[i] - 1;
                    end else begin
                        backwards_rotor_iii[i] <= 5'd26;
                    end 
                end 
            end     
	    ready <= 1;
	end else begin
            data_valid_out_pipeline[0] <= 0;
        end
        //Data Movement continued
        data_pipeline[1] <= rotor_ii[26-data_pipeline[0]];
        data_valid_out_pipeline[1] <= data_valid_out_pipeline[0];
        data_pipeline[2] <= rotor_iii[26-data_pipeline[1]];
        data_valid_out_pipeline[2] <= data_valid_out_pipeline[1];
        data_pipeline[3] <= reflector[26-data_pipeline[2]];
        data_valid_out_pipeline[3] <= data_valid_out_pipeline[2];
        data_pipeline[4] <= backwards_rotor_iii[26-data_pipeline[3]];
        data_valid_out_pipeline[4] <= data_valid_out_pipeline[3];
        data_pipeline[5] <= backwards_rotor_ii[26-data_pipeline[4]];
        data_valid_out_pipeline[5] <= data_valid_out_pipeline[4];
        data_out <= backwards_rotor_i[26-data_pipeline[5]];
        data_valid_out <= data_valid_out_pipeline[5];
    end

endmodule

`default_nettype wire
