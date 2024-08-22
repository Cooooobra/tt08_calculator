/*
 * Copyright (c) 2024 JING Shuangyu
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_shuangyu_top (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);


  // // All output pins must be assigned. If not used, assign to 0.
  // // assign uo_out  = ui_in + uio_in;  // Example: uo_out is the sum of ui_in and uio_in
  // // assign uio_out = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in[7:4], 1'b0};

  assign uio_oe[7:0] = 8'b1111_1111;  //bir all for output

  wire [7:0] SevenSegment;  
  assign uo_out[0] = SevenSegment[0];  //A
  assign uo_out[1] = SevenSegment[1];  //B
  assign uo_out[2] = SevenSegment[2];  //C
  assign uo_out[3] = SevenSegment[3];  //D
  assign uo_out[4] = SevenSegment[4];  //E
  assign uo_out[5] = SevenSegment[5];  //F
  assign uo_out[6] = SevenSegment[6];  //G
  assign uo_out[7] = SevenSegment[7];  //dp

  wire [3:0] Enable;
  assign uio_out[0] = Enable[0];
  assign uio_out[1] = Enable[1];
  assign uio_out[2] = Enable[2];
  assign uio_out[3] = Enable[3];

  wire [3:0] IO_P4_COL;
  assign uio_out[5] = IO_P4_COL[0];
  assign uio_out[6] = IO_P4_COL[1];
  assign uio_out[7] = IO_P4_COL[2];
  assign uio_out[8] = IO_P4_COL[3];
 
  
  

  // calculator_top inst_calculator(
  //     .clk(clk),
  //     .rst_n(rst_n),
  //     .IO_P4_ROW(ui_in[3:0]),
  //     .IO_P4_COL(IO_P4_COL),
  //     .Enable(Enable),
  //     .SevenSegment(SevenSegment)
  // );

//calculator operator
localparam [1:0]
   OP_PLUS = 2'd0,
   OP_MINUS = 2'd1,
   OP_MULTIPLY = 2'd2,
   OP_DIVIDE = 2'd3;


//calculator state
reg [3:0] state; 
localparam [3:0] 
   state_clear = 4'd0,
   state_read = 4'd1,
   state_digit_pressed = 4'd2,
   state_minus_pressed = 4'd3,
   state_dp_pressed = 4'd4,
   state_plus_pressed = 4'd5,
   state_multiply_pressed = 4'd6,
   state_divide_pressed = 4'd7,
   state_calculate = 4'd8,
   state_display_arg = 4'd9,
   state_display_result = 4'd10;


reg [2:0] reg_digits_counter;  
reg [2:0] reg_decimal_place_counter;  
reg [1:0] reg_sign;  //OP_PLUS or OP_MINUS
reg reg_dp;
reg reg_error;
reg [1:0] reg_operator;
reg [1:0] reg_operator_next;
reg signed [24:0] reg_arg;
reg signed [34:0] reg_result;  
reg signed [24:0] reg_display;


wire key_pressed;
reg key_pressed_prev;  //check if new key come in


wire [3:0] keypad_out;
wire [3:0] keypad_poller_row;
wire [3:0] keypad_poller_column;


/* verilator lint_off UNUSEDSIGNAL */
wire [24:0] data_display;
wire neg_sign;
wire neg_display;
wire dp_display;
wire [3:0] dp_position;
wire [15:0] num_bcd_display;
/* verilator lint_on UNUSEDSIGNAL */


// component
sign_display inst_sign_display(
    .clk(clk),
    .rst_n(rst_n),
    .num(reg_display),
    .sign(reg_sign),
    .abs_num(data_display),
    .neg(neg_sign)
);

pre_display inst_pre_display(
    .clk(clk),
    .rst_n(rst_n),
    .data(data_display),
    .neg(neg_sign),
    .frac(reg_dp),
    .error(reg_error),
    .reg_neg(neg_display),
    .reg_frac(dp_display),
    .dp_position(dp_position),
    .reg_num(num_bcd_display)
);

drive inst_drive(
    .clk(clk),
    .rst_n(rst_n),
    .en(1'b1),
    .bcd(num_bcd_display),
    .frac(dp_display),
    .dp(dp_position),
    .seg_sel(Enable),
    .seg_led(SevenSegment)
);

keypad_poller inst_keypad_poller(
    .clk(clk),
    .rst_n(rst_n),
    .keypad_row_in(ui_in[3:0]), //!
    .keypad_col_out(keypad_poller_column),
    .row_out(keypad_poller_row),
    .key_pressed(key_pressed)
);

keypad_encoder inst_keypad_encoder(
    .clk(clk),
    .rst_n(rst_n),
    .rows(keypad_poller_row),
    .cols(keypad_poller_column),
    .key(keypad_out)
);


	
always @(posedge clk or negedge rst_n)
begin
	if(!rst_n) begin
		state <= state_clear;
    	reg_error <= 1'b0;
  	end 
  	else begin
    	case(state)
      		state_clear: begin
      			reg_digits_counter <= 0; 
      			reg_decimal_place_counter <= 3'd1;  //initial to be 1
      			reg_sign <= OP_PLUS;
      			reg_dp <= 0;
      			//reg_error <= 0;
      			reg_operator <= OP_PLUS;
      			reg_operator_next <= OP_PLUS;
      			reg_arg <= 0;
      			reg_result <= 0;
      			reg_display <= 0;
      			key_pressed_prev <=0;  
      			// clear -> read
      			state <= state_read;
      		end
      		state_read: begin
        		// check if new key come in
        		if(key_pressed && !key_pressed_prev) begin
			        reg_error <= 1'b0;  //!
	  				if(keypad_out < 4'hA) begin
            			state <= state_digit_pressed;
          			end
          			else if(keypad_out == 4'hA) begin
	    				state <= state_plus_pressed;
          			end
          			else if(keypad_out == 4'hB) begin
	    				state <= state_minus_pressed;
          			end
          			else if(keypad_out == 4'hC) begin
	    				state <= state_multiply_pressed;
          			end
          			else if(keypad_out == 4'hD) begin
	    				state <= state_divide_pressed;
          			end
          			else if(keypad_out == 4'hF) begin
            			state <= state_dp_pressed;
          			end
          			else if(keypad_out == 4'hE) begin
             			state <= state_clear;
          			end
        		end
        		key_pressed_prev <= key_pressed;
      		end
      		state_digit_pressed: begin
        		/* verilator lint_off WIDTHEXPAND */
        		if(reg_sign == OP_PLUS) begin  // positive input
          			if(reg_digits_counter < 4) begin  //legal input at most 4 digits
            			if(!reg_dp) begin  // integer part
              				reg_arg <= reg_arg * 10 + (keypad_out * (10 ** 3));  
            			end
            			else begin  // decimal part
              				reg_arg <= reg_arg + (keypad_out * (10 ** (3 - reg_decimal_place_counter)));
              				reg_decimal_place_counter <= reg_decimal_place_counter + 1;
            			end
            			reg_digits_counter <= reg_digits_counter + 1;
            			state <= state_display_arg;
          			end
          			else begin  //illegal input
            			reg_error <= 1;
            			//state <= state_display_error;
            			state <= state_clear;
          			end
        		end
        		else begin  // negative input
          			if(reg_digits_counter < 3) begin  //legal input at most 3 digits                        
            			if(!reg_dp) begin
				            reg_arg <= reg_arg * 10 + (~(keypad_out * (10 ** 3)) + 1);  
            			end
            			else begin
              				reg_decimal_place_counter <= reg_decimal_place_counter + 1;
              				reg_arg <= reg_arg + (~(keypad_out * (10 ** (3 - reg_decimal_place_counter))) + 1);
            			end
            			reg_digits_counter <= reg_digits_counter + 1;     
            			state <= state_display_arg;
          			end  
          			else begin
            			reg_error <= 1;
            			//state <= state_display_error;
            			state <= state_clear;
          			end
        		end
        		/* verilator lint_on WIDTHEXPAND */
      		end
            state_minus_pressed: begin
                reg_sign <= OP_MINUS; 
				state <= state_display_arg;  //display minus sign
			end
			state_dp_pressed: begin
                if(!reg_dp) begin
                    reg_dp <= 1;
                    state <= state_display_arg;
                end
                else begin  //illegal input - no more than 1 decimal point
                    reg_error <= 1;
                    //state <= state_display_error;
                    state <= state_clear;
                end
            end
			state_plus_pressed: begin
                reg_operator_next <= OP_PLUS;
			 	state <= state_calculate; 
            end
			state_multiply_pressed: begin
				reg_operator_next <= OP_MULTIPLY;
				state <= state_calculate;
			end
			state_divide_pressed: begin
				reg_operator_next <= OP_DIVIDE;
				state <= state_calculate;
			end
            state_calculate: begin
                // addition
				if(reg_operator == OP_PLUS) begin
                    /* verilator lint_off WIDTHEXPAND */
                    reg_result <= reg_result + reg_arg;
                    /* verilator lint_on WIDTHEXPAND */
					state <= state_display_result;
                end 
                // multiplication
                else if(reg_operator == OP_MULTIPLY) begin
                    /* verilator lint_off WIDTHEXPAND */
                    reg_result <= (reg_result * reg_arg) / (10 ** 3); 
                    /* verilator lint_on WIDTHEXPAND */
					state <= state_display_result;
				end 
                // division
                else if(reg_operator == OP_DIVIDE) begin
                    /* verilator lint_off WIDTHEXPAND */
                    reg_result <= (reg_result * (10 ** 3)) / reg_arg;
                    /* verilator lint_on WIDTHEXPAND */
					state <= state_display_result;
				end 
				reg_operator <= reg_operator_next;
			end
            state_display_arg: begin
                reg_display <= reg_arg;
				state <= state_read;
			end
			state_display_result: begin
                // check overflow
                if((reg_result - (9999 * (10 ** 3))) > 0 || (reg_result + (999 * (10 ** 3)) < 0)) begin
                    reg_error <= 1;
                    //state <= state_display_error;
                    state <= state_clear;
                end 
                else begin
                    reg_display <= reg_result[24:0];
					state <= state_read;
                end
                //reset some registers
                reg_digits_counter <= 0; 
                reg_decimal_place_counter <= 3'd1; 
                reg_sign <= OP_PLUS;
                reg_dp <= 0;
                reg_arg <= 0;
			end
			default: begin
            end
		endcase
	end
end


assign IO_P4_COL = keypad_poller_column;

    
endmodule
