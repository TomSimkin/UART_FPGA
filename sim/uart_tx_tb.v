`timescale 1ns/1ps // Every #1 delay is 1ns, simulator precision is 1ps

`define SIM	

`include "uart_tx.v"


module uart_tx_tb();

// Parameters
localparam integer clk_frequency   		= 27_000_000;       				// Clock frequency (27 MHz)
localparam integer baud_rate  			= 115_200;							// Serial baud rate
localparam integer cycles_per_bit 		= clk_frequency / baud_rate;		// ≈ 234 clock cycles
localparam real    clk_period 			= 1_000_000_000.0 / clk_frequency;  // ≈ 37.037 ns system clock period, 234 clock cycles make up 1 UART bit

// Signals
reg         clk 			= 0; 	// Clock input
reg         rst_n 			= 0; 	// Asynchronous reset input, low active
reg [7:0] 	data_send		= 0;	// Data to send
reg 		tx_valid		= 0;	// Tx ready to send data
wire 		ready_tx;				// Tx ready to work on new byte 
wire 		o_tx;					// Serial data output
wire [7:0] 	debug_frame; 			// End result

// Uart_tx instantiation 	
uart_tx
#(
	.clk_frequency(clk_frequency / 1_000_000), // 27 MHz -> 27 in uart_rx
	.baud_rate(baud_rate)
)
DUT
(
    .i_clk    	 (clk),
    .i_rst_n   	 (rst_n),
    .data_send 	 (data_send),
    .tx_valid  	 (tx_valid),
    .ready_tx  	 (ready_tx),
    .o_tx      	 (o_tx),
	.debug_frame (debug_frame)
);

// Clock pulse  
initial 
begin
	clk = 0;
	forever #(clk_period / 2) clk = ~clk;
end

// Reset pulse
initial 
begin
	rst_n = 0;
	repeat (10) @(posedge clk);
	rst_n = 1;
end

// Send a byte when ready_tx is asserted
task send_byte;
	input [7:0] data;
	integer 	i;
	begin
		// Wait for DUT to be ready
		wait (ready_tx == 1'b1);
		
		// Give data_send the data byte for 1 cc
		data_send = data;
		tx_valid = 1'b1;
		@(posedge clk);
		tx_valid = 1'b0;
	end
endtask

integer errors = 0;			// Count number of errors test sequence

// Test sequence
initial 
begin
	// Wait for reset 
	@(posedge rst_n);

	// Test 1 - good frame
	send_byte(8'h5A);
	
	// Wait 1 cc so debug_frame updates
	wait (ready_tx == 1'b0);  
	@(posedge clk);           
	
	if (debug_frame != 8'h5A)
	begin
		$display ("FAIL TEST1: got %02h, expected %02h", debug_frame, 8'h5A);
		errors = errors + 1;
	end
	else
		$display ("PASS TEST1");
		
	// Test 2 - all zeros	
	send_byte(8'h00);
	
	wait (ready_tx == 1'b0);  
	@(posedge clk);  
	
	if (debug_frame !== 8'h00) 
	begin
		$display("FAIL TEST2: got %02h, expected %02h", debug_frame, 8'h00);
		errors = errors + 1;
	end else
	  $display("PASS TEST2");	
	
	// Test 3: all ones
	send_byte(8'hFF);
	
	wait (ready_tx == 1'b0);  
	@(posedge clk);  
	
	if (debug_frame !== 8'hFF) 
	begin
		$display("FAIL TEST3: got %02h, expected %02h", debug_frame, 8'hFF); 
		errors = errors + 1;
	end
	else
		$display("PASS TEST3");
		
	// Test 4 - back-to-back throughput
	send_byte(8'hAA);
	
	wait (ready_tx == 1'b1); // as soon as TX is idle, send next
	
	send_byte(8'hAA);
	
	wait (ready_tx == 1'b0);  
	@(posedge clk);  
	
	if (debug_frame !== 8'hAA) 
	begin
		$display("FAIL TEST4: got %02h, expected %02h", debug_frame, 8'hAA);
		errors = errors + 1;
	end 
	else $display("PASS TEST4");
		
	$display("TEST COMPLETE: %0d error(s)", errors);
end

endmodule