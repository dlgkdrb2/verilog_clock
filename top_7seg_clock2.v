module top_7seg_clock2(clk_100MHz, reset, B0, B1, blink, seg);
	input clk_100MHz, reset, B0, B1;
	output blink;
	output [48:0] seg;
	
	wire [5:0] v_seconds, v_minutes, v_hours;
	wire [2:0] hrs_tens, mins_tens, secs_tens;
	wire [3:0] hrs_ones, mins_ones, secs_ones;
	wire [3:0] state;
	
	controller ctr (.clk(clk_100MHz), .reset(reset), .B0(B0), .B1(B1), .state(state));
	
	middle_7seg_clock middle (.clk_100MHz(clk_100MHz), .reset(reset), .state(state), .B0(B0), .B1(B1), 
	.blink(blink), .hrs_tens(hrs_tens), .hrs_ones(hrs_ones), .mins_tens(mins_tens), .mins_ones(mins_ones), .secs_tens(secs_tens), .secs_ones(secs_ones));
	
	seg7_control seg7(.clk_100MHz(clk_100MHZ), .reset(reset), .hrs_tens(hrs_tens), .hrs_ones(hrs_ones), .mins_tens(mins_tens), .mins_ones(mins_ones), 
	.secs_tens(secs_tens), .secs_ones(secs_ones), .state(state), .seg(seg));
endmodule

module middle_7seg_clock(clk_100MHz, reset, state, B0, B1, blink, hrs_tens, hrs_ones, mins_tens, mins_ones, secs_tens, secs_ones);
	input clk_100MHz, reset, B0, B1;
	input [3:0] state;
	output blink;
	output [2:0] hrs_tens, mins_tens, secs_tens;
	output [3:0] hrs_ones, mins_ones, secs_ones;
	
	wire [5:0] v_seconds, v_minutes, v_hours;

	
	top_bin_clock bin(.clk_100MHz(clk_100MHz), .reset(reset), .state(state), .B0(B0), .B1(B1), .sig_1Hz(blink), .hours(v_hours), .minutes(v_minutes), .seconds(v_seconds));
	
	// display
	bin2bcd2 hrs(.bin_in(v_hours), .tens(hrs_tens), .ones(hrs_ones));
	bin2bcd1 mins(.bin_in(v_minutes), .tens(mins_tens), .ones(mins_ones));
	bin2bcd1 secs(.bin_in(v_seconds), .tens(secs_tens), .ones(secs_ones));
endmodule

module controller(clk, reset, B0, B1, state);
	input clk, reset, B0, B1;
	output [3:0] state;
	reg [3:0] state_t;
	localparam s00=1, s01=2, s02=3, s10=5, s11=6, s12=7, s20=9, s21=10, s22=11;
	
	always @(posedge clk or posedge reset) begin
		if (reset) state_t <= s00;
		else begin
			state_t <= s00;
			case (state_t)
				// clock
				s00:	if(B0) state_t <= s10; // to stop_watch
						else if(B1) state_t <= s01; // clock_set
	
				s01:	if(B1) state_t <= s02; // hour set 
				s02:	if(B1) state_t <= s00; // min set
			
				s10:	if(B0) state_t <= s20; // to alarm set
						else if(B1) state_t <= s11; // stop_watch run
				s11:	if(B0) state_t <= s12; // to pause
				s12:	if(B0) state_t <= s11; // to run
						else if(B1) state_t <= s10; // to stop

				s20:	if(B0) state_t <= s00; // to clock
						else if(B1) state_t <= s21; // to alarm hour set
				s21:	if(B1) state_t <= s22; // to alarm min set
				s22:	if(B1) state_t <= s20; // to alarm set
				default: state_t <= s00;
			endcase
		end
	end

	assign state = state_t;
endmodule

// button pulse
module btn_debouncer(clk_100MHz, btn_in, btn_out);
	input clk_100MHz, btn_in;
	output btn_out;
	
	reg temp1, temp2, temp3;
	
	always @(posedge clk_100MHz) begin
		temp1 <= btn_in;
		temp2 <= temp1;
		temp3 <= temp2;
	end
	assign btn_out = temp3;
endmodule

// 1second
module oneHz_generator(clk_100MHz, clk_1Hz);
	input clk_100MHz;
	output clk_1Hz;
	
	reg [25:0] counter_reg = 0;
	reg clk_out_reg = 0;
	
	always @(posedge clk_100MHz) begin
		if(counter_reg == 24_999_999) begin
			counter_reg <= 0;
			clk_out_reg <= ~clk_out_reg;
		end
		else counter_reg <= counter_reg + 1;
	end
	
	assign clk_1Hz = clk_out_reg;
	
endmodule

// second
module seconds(clk_1Hz, reset, inc_minutes, seconds);
	input clk_1Hz, reset;
	output inc_minutes;
	output [5:0] seconds;
	
	reg [5:0] sec_ctr;
	
	always @(posedge clk_1Hz or posedge reset) begin
		if(reset) sec_ctr <= 0;
		else 
			if(sec_ctr == 59) sec_ctr <= 0;
			else sec_ctr <= sec_ctr + 1;
	end
	
	assign inc_minutes = (sec_ctr == 59) ? 1 : 0;
	assign seconds = sec_ctr;
endmodule


// minute
module minutes(inc_minutes, reset, inc_hours, minutes);
	input inc_minutes, reset;
	output inc_hours;
	output [5:0] minutes;
	
	reg [5:0] min_ctr;
	
	always @(negedge inc_minutes or posedge reset) begin
		if(reset) min_ctr <= 0;
		else 
			if(min_ctr == 59) min_ctr <= 0;
			else min_ctr <= min_ctr + 1;
	end
	
	assign inc_hours = (min_ctr == 59) ? 1 : 0;
	assign minutes = min_ctr;
endmodule

// hour
module hours(inc_hours, reset, hours);
	input inc_hours, reset;
	output [5:0] hours;
	
	reg [5:0] hrs_ctr;
	
	always @(negedge inc_hours or posedge reset) begin
		if(reset) hrs_ctr <= 0;
		else
			if(hrs_ctr==23) hrs_ctr <= 0;
			else hrs_ctr <= hrs_ctr + 1;
	end
	
	assign hours = hrs_ctr;
endmodule

// 
module top_bin_clock(clk_100MHz, reset, state, B1, B0, hours, sig_1Hz, minutes, seconds);
	input clk_100MHz, reset, B1, B0;
	input [3:0] state;
	output [5:0] hours;
	output sig_1Hz;
	output [5:0] minutes, seconds;
	wire w_1Hz;
	wire B0_db, reset_db, B1_db;
	wire w_inc_mins, w_inc_hrs;
	wire inc_mins_or, inc_hrs_or;
	
	btn_debouncer bL(.clk_100MHz(clk_100MHz), .btn_in(B0), .btn_out(B0_db));
	btn_debouncer bC(.clk_100MHz(clk_100MHz), .btn_in(reset), .btn_out(reset_db));
	btn_debouncer bR(.clk_100MHz(clk_100MHz), .btn_in(B1), .btn_out(B1_db));
	
	oneHz_generator uno(.clk_100MHz(clk_100MHz), .clk_1Hz(w_1Hz));
	
	seconds sec(.clk_1Hz(sig_1Hz), .reset(reset_db), .inc_minutes(w_inc_mins), .seconds(seconds));
	minutes min(.inc_minutes(inc_mins_or), .reset(reset_db), .inc_hours(w_inc_hrs), .minutes(minutes));
	hours hr(.inc_hours(inc_hrs_or), .reset(reset_db), .hours(hours));
	
	assign sig_1Hz = w_1Hz;
	assign inc_mins_or = (w_inc_mins | ~B1_db);
	assign inc_hrs_or = (w_inc_hrs | ~B0_db); 
	
	/// only counter
	/*
	assign sig_1Hz = w_1Hz;
	assign inc_mins_or = w_inc_mins;
	assign inc_hrs_or = w_inc_hrs; 
*/
	/// problem >> w_inc_mins
	/*
	assign sig_1Hz = w_1Hz;
	assign inc_mins_or = (w_inc_mins | B1_db);
	assign inc_hrs_or = (w_inc_hrs | B0_db); 
	*/
	
	///// clock, setclock - use state (problem >> state)
	/*
	assign sig_1Hz = ((state==1 | state==6) ? w_1Hz : 0);
	assign inc_mins_or = ((state==1 | state==6) ? w_inc_mins : ((state==3) ? B0_db : inc_mins_or));
	assign inc_hrs_or = ((state==1 | state==6) ? w_inc_hrs : ((state==2) ? B0_db : inc_hrs_or));
*/
endmodule

//
module bin2bcd1( bin_in, tens, ones);
	input [5:0] bin_in;
	output reg [2:0] tens;
	output reg [3:0] ones;
	
	always @* begin
		tens <= bin_in / 10;
		ones <= bin_in % 10;
	end
endmodule

//
module bin2bcd2( bin_in, tens, ones);
	input [5:0] bin_in;
	output reg [2:0] tens;
	output reg [3:0] ones;
	
	always @* begin
		if(bin_in<10) begin tens<=0; ones <=bin_in; end
		else if(bin_in<20) begin tens<=1; ones <= bin_in % 10; end
		else begin tens <= 2; ones <= bin_in % 10; end
	end
endmodule

//
module seg7_control(clk_100MHz, reset, hrs_tens, hrs_ones, mins_tens, mins_ones, secs_tens, secs_ones, state, seg);
	input clk_100MHz, reset;
	input [2:0] hrs_tens, mins_tens, secs_tens;
	input [3:0] hrs_ones, mins_ones, secs_ones;
	input [3:0] state;
	output reg [48:0] seg;
	
	always @(*)begin
		case(state)
		1: seg = { 7'b100_1111, seg[41:0]};
		2: seg = { 7'b001_0010, seg[41:0]};
		3: seg = { 7'b000_0110, seg[41:0]};
		5: seg = { 7'b010_0100, seg[41:0]};
		6: seg = { 7'b010_0000, seg[41:0]};
		7: seg = { 7'b000_1111, seg[41:0]};
		default : seg = { 7'b111_1111, seg[41:0] };
		endcase
	end
	
	always @(*)begin
		case(hrs_tens)
		0: seg = { seg[48:42], 7'b000_0001, seg[34:0]  }; 
		1: seg = { seg[48:42], 7'b100_1111, seg[34:0]  }; 
		2: seg = { seg[48:42], 7'b001_0010, seg[34:0] };  
		default:  seg = { seg[48:42], 7'b111_1111, seg[34:0] }; 
		endcase
	end
	
	always @(*)begin
		case(hrs_ones)
		0: seg = { seg[48:35], 7'b000_0001, seg[27:0]   }; 
		1: seg={seg[48:35], 7'b100_1111, seg[27:0]   };
		2: seg={seg[48:35], 7'b001_0010, seg[27:0]   };
		3: seg={seg[48:35], 7'b000_0110, seg[27:0]   };
		4: seg={seg[48:35], 7'b100_1100, seg[27:0]   };
		5: seg={seg[48:35], 7'b010_0100, seg[27:0]   };
		6: seg={seg[48:35], 7'b010_0000, seg[27:0]   };
		7: seg={seg[48:35], 7'b000_1111, seg[27:0]   };
		8: seg={seg[48:35], 7'b000_0000, seg[27:0]   };
		9: seg={seg[48:35], 7'b000_0100, seg[27:0]   };		
		default:  seg = {seg[48:35], 7'b111_1111, seg[27:0]   };
		endcase
	end
	
	always @(*)begin
		case(mins_tens)
		0: seg={ seg[48:28],7'b000_0001, seg[20:0]}; 
		1: seg={ seg[48:28],7'b100_1111, seg[20:0]};  
		2: seg={ seg[48:28],7'b001_0010, seg[20:0]};  
		3: seg={ seg[48:28],7'b000_0110, seg[20:0]};  
		4: seg={ seg[48:28],7'b100_1100, seg[20:0]};  
		5: seg={ seg[48:28],7'b010_0100, seg[20:0]};   
		default:  seg={ seg[48:28],7'b111_1111, seg[20:0]};  
		endcase
	end
	
	always @(*)begin
		case(mins_ones)
		0: seg={ seg[48:21],7'b000_0001, seg[13:0]};  
		1: seg={ seg[48:21],7'b100_1111, seg[13:0]};  
		2: seg={ seg[48:21],7'b001_0010, seg[13:0]};  
		3: seg={ seg[48:21],7'b000_0110, seg[13:0]};  
		4: seg={ seg[48:21],7'b100_1100, seg[13:0]};  
		5: seg={ seg[48:21],7'b010_0100, seg[13:0]};  
		6: seg={ seg[48:21],7'b010_0000, seg[13:0]}; 
		7: seg={ seg[48:21],7'b000_1111, seg[13:0]}; 
		8: seg={ seg[48:21],7'b000_0000, seg[13:0]}; 
		9: seg={ seg[48:21],7'b000_0100, seg[13:0]}; 
		default:  seg={ seg[48:21],7'b111_1111, seg[13:0]}; 
		endcase
	end
	
	always @(*)begin
		case(secs_tens)
		0: seg={ seg[48:14],7'b000_0001, seg[6:0]}; 
		1: seg={ seg[48:14],7'b100_1111, seg[6:0]};  
		2: seg={ seg[48:14],7'b001_0010, seg[6:0]};  
		3: seg={ seg[48:14],7'b000_0110, seg[6:0]};  
		4: seg={ seg[48:14],7'b100_1100, seg[6:0]};  
		5: seg={ seg[48:14],7'b010_0100, seg[6:0]};   
		default:  seg={ seg[48:14],7'b111_1111, seg[6:0]};  
		endcase
	end
	
	always @(*)begin
		case(secs_ones)
		0: seg={ seg[48:7],7'b000_0001};  
		1: seg={ seg[48:7],7'b100_1111};  
		2: seg={ seg[48:7],7'b001_0010};  
		3: seg={ seg[48:7],7'b000_0110};  
		4: seg={ seg[48:7],7'b100_1100};  
		5: seg={ seg[48:7],7'b010_0100};  
		6: seg={ seg[48:7],7'b010_0000}; 
		7: seg={ seg[48:7],7'b000_1111}; 
		8: seg={ seg[48:7],7'b000_0000}; 
		9: seg={ seg[48:7],7'b000_0100}; 
		default:  seg={ seg[48:7],7'b111_1111}; 
		endcase
	end
endmodule

//

