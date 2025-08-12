`timescale 1ns/1ps // Every #1 delay is 1ns, simulator precision is 1ps

`include "uart_rx.v"

module uart_rx_tb();

// Parameters
localparam integer clk_frequency   		= 27_000_000;       				// Clock frequency (27 MHz)
localparam integer baud_rate  			= 115_200;							// Serial baud rate
localparam integer cycles_per_bit 		= clk_frequency / baud_rate;		// ≈ 234 clock cycles
localparam real    clk_period 			= 1_000_000_000.0 / clk_frequency;  // ≈ 37.037 ns system clock period, 234 clock cycles make up 1 UART bit

// Signals
reg         clk 			= 0; 	// Clock input
reg         rst_n 			= 0; 	// Asynchronous reset input, low active
reg         i_byte_accept 	= 0; 	// Rx ready to receive data
reg         i_data_bit    	= 1;  	// Serial data input, idle state = '1'
wire        o_done; 				// Rx finished process
wire [7:0]  o_data_byte;			// Received byte of data 
wire        framing_error;			// Flag for correct/incorrect stop bit 

// Uart_rx instantiation 
uart_rx 
#(
	.clk_frequency(clk_frequency / 1_000_000), // 27 MHz -> 27 in uart_rx
	.baud_rate(baud_rate)
)
DUT
(
	.i_clk         (clk),
    .i_rst_n       (rst_n),
    .i_byte_accept (i_byte_accept),
    .i_data_bit    (i_data_bit),
    .o_done        (o_done),
    .o_data_byte   (o_data_byte),
    .framing_error (framing_error)
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

// Drive one UART bit for exactly cycles_per_bit clocks
task uart_bit;
	input b;
	integer counter;
	begin
		i_data_bit = b;
		repeat (cycles_per_bit) @(posedge clk);
	end
endtask

// One‐cycle–pulse acknowledge
task ack_frame;
begin
  #1;                   // Tiny delta so o_done has settled
  i_byte_accept = 1;    // Blocking assign
  @(posedge clk);       // Let the DUT sample it
  i_byte_accept = 0;    // Back to zero
end
endtask

// Good frame : start, data LSB -> MSB, stop, extra idle
task send_frame;
	input [7:0] data;
	integer i;
	begin
		// Ensure at least one idle bit before data
		uart_bit(1'b1);

		// Send start bit
		uart_bit(1'b0);
		
		// Send data byte
		for (i = 0; i < 8; i = i + 1)
			uart_bit(data[i]);
				
		// Send stop bit + 1 extra idle bit
		uart_bit(1'b1);
		uart_bit(1'b1);
	end
endtask 

// Framing-error frame
task send_frame_framing_error;
	input [7:0] data;
	integer i;
	begin
		// Ensure at least one idle bit before data
		uart_bit(1'b1);

		// Send start bit
		uart_bit(1'b0);
		
		// Send data byte
		for (i = 0; i < 8; i = i + 1)
			uart_bit(data[i]);
				
		// Send bad stop bit + 1 extra idle bit
		uart_bit(1'b0);
		uart_bit(1'b1);
	end
endtask 

// Raw frame (no extra idle beyond stop)
task send_frame_raw;
    input [7:0] data;
    integer i;
    begin
		// Start bit 
        uart_bit(1'b0); 
		
		// Send data byte
        for (i = 0; i < 8; i = i + 1) 
			uart_bit(data[i]);
		
		// Stop bit
        uart_bit(1'b1); // stop
    end
endtask

integer errors = 0; // Count number of errors test sequence

// Test sequence
initial 
begin
	// Wait for reset 
	@(posedge rst_n);
	
	// Test 1 - good frame
	send_frame(8'h5A);
	
	// Wait for the Rx to signal "done"
	wait (o_done == 1);
	
	// Verify results
	if (o_data_byte != 8'h5A || framing_error)
	begin
		$display ("FAIL TEST1: got %02h, f_error = %b", o_data_byte, framing_error);
		errors = errors + 1;
	end
	else
		$display ("PASS TEST1: got %02h, f_error = %b", o_data_byte, framing_error);
	
	ack_frame();
	
	// Wait for next test
	wait (o_done == 0);
	repeat (cycles_per_bit) @(posedge clk);
	
	// Test 2 - framing-error frame
	send_frame_framing_error(8'h5B); 
	
	// Wait for the Rx to signal "done"
	wait (o_done == 1);
	
	if (!framing_error) 
	begin
		$display("FAIL TEST2: got %02h, f_error = %b", o_data_byte, framing_error);
		errors = errors + 1;
	end 
	else
		$display("PASS TEST2: got %02h, f_error = %b", o_data_byte, framing_error);
	
	ack_frame();
	
	// Wait for next test
	wait (o_done == 0);
	repeat (cycles_per_bit) @(posedge clk);
	
	// Test 3 - two frames with minimal gap (ack between frames)
	// Ensure initial idle
	uart_bit(1'b1); 	
	
	// First frame no extra idle beyond stop
	send_frame_raw(8'h5C); 

	wait (o_done == 1);
	
	if (o_data_byte != 8'h5C || framing_error) 
	begin
        $display("FAIL TEST3a: got %02h, f_error=%b", o_data_byte, framing_error);
        errors = errors + 1;
    end 
	else 
		$display("PASS TEST3a: got %02h", o_data_byte);
    
	ack_frame();
	
    wait (o_done == 0);
	
	// Immediately send second frame (only required stop gap)
    send_frame_raw(8'h5D);
    wait (o_done == 1);
    if (o_data_byte != 8'h5D || framing_error) 
	begin
        $display("FAIL TEST3b: got %02h, f_error=%b", o_data_byte, framing_error);
        errors = errors + 1;
    end 
	else 
		$display("PASS TEST3b: got %02h", o_data_byte);
		
    ack_frame();
	
    wait (o_done == 0);
	
	$display("TEST COMPLETE: %0d error(s)", errors);
	
end

endmodule