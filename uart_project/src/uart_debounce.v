module uart_debounce
#(
	parameter integer CLK_FREQ = 27_000_000, 	// 27 MHz clock
	parameter integer HOLD_MS  = 5				// Require 5 ms of stability
)
(
	input 	wire 	clk,		// System clock
	input 	wire 	btn_press,	// Raw, unsynchronized button press
	output 	reg 	btn_result	// Debounced button press
);

localparam integer hold_max = (CLK_FREQ / 1000) * HOLD_MS; 	// HOLD_MS ms worth of clock cycles:
															// (CLK_FREQ / 1000) = 27_000 clocks per ms * HOLD_MS = 135_000 clocks per 5ms	

// Count cycles	button is held								  
reg [17:0] counter = 0;

// FF's (delays) to avoid metastability	
reg 	   sync1 = 1'b1;
reg        sync2 = 1'b1;						  

// Initial output is 1 (not pressed)
initial 
begin
    btn_result = 1'b1;
end

// Synchronizer
always @(posedge clk)
begin
	sync1 <= btn_press;
	sync2 <= sync1;
end

wire btn_debounced = sync2;

// Debounce counter 
always @(posedge clk)
begin
	if (sync2 == btn_result)		// No change
		counter <= 0;
	else if (counter == hold_max) 	// Button held long enough
	begin
		btn_result <= btn_debounced;
		counter <= 0;
	end
	else
		counter <= counter + 18'd1;
end

endmodule