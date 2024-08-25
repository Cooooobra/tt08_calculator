/*
 * Copyright (c) 2024 JING Shuangyu
 * SPDX-License-Identifier: Apache-2.0
 */

 /* verilator lint_off UNUSEDSIGNAL */

`default_nettype none
//`timescale 1ns / 1ps

/*
calculator
*/

module calculator(
    input clk,
    input rst_n,
	input key_pressed,
	input [3:0] keypad_out,
	output reg signed [24:0] reg_display
);


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
//reg signed [24:0] reg_display;


//wire key_pressed;
reg key_pressed_prev;  //check if new key come in



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


endmodule
/* verilator lint_on UNUSEDSIGNAL */
