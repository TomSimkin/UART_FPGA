module uart_top
(
	input 	wire clk, 				// On-board 27 MHz oscillator 						(PIN 4)
	input 	wire rst_btn, 			// On-board reset button, active-low 				(PIN 88)
	input 	wire BL616_UART_RX, 	// Data into FPGA receive input (i_data_bit) 		(PIN 70)
	output 	wire BL616_UART_TX, 	// Data from FPGA transmit output (o_tx) 			(PIN 69)
	// All LEDs are active LOW (0 = ON, 1 = OFF)
	output 	reg LED0, 				// Heartbeat (slow blink to know the FPGA is alive) (PIN 15)
	output	reg LED1,				// Rx activity - pulse on every received byte		(PIN 16)
	output 	reg LED2,				// Tx activity - pulse on every transmitted byte	(PIN 17)
	output 	reg LED3,				// Framing error									(PIN 18)
	output 	wire LED4				// Reset indicator - ON during system reset 		(PIN 19)
);

// Reset signals
wire rst_active, rst_n; 
assign rst_n = ~rst_active; // Convert to active-low

// Uart_debounce instantiation 
uart_debounce
#(
	.CLK_FREQ	(27_000_000),
	.HOLD_MS 	(5)
)
DEBOUNCE
(
	.clk 		(clk),
	.btn_press 	(rst_btn),
	.btn_result (rst_active)    // '1' when button pressed after debounce
);

// Rx signals
wire 		rx_done;			// Finished receiving data
wire [7:0] 	rx_data;			// Data storage 
wire 		rx_framing_err; 	// Framing error flag
reg 		rx_ack;				// Accepted new data byte
reg 		error_detect;		// Error detection
reg [7:0]   rx_data_latched;    // Latched received data
reg [25:0]  delay_counter;      // Delay counter for 1-second delay (26 bits for 27MHz cycles)
reg         delay_active;       // Flag to indicate delay is in progress

// Tx signals
reg 	tx_valid;				// Pulse to start transmit of rx_data 
wire 	tx_ready;				// Ready to work on new byte, is idle

// Uart_rx instantiation 
uart_rx 
#(
	.clk_frequency(27), 		// 27 MHz 
	.baud_rate(115200)			// 115200 baud rate
)
RX
(
	.i_clk         (clk),
    .i_rst_n       (rst_n),
    .i_byte_accept (rx_ack),
    .i_data_bit    (BL616_UART_RX),
    .o_done        (rx_done),
    .o_data_byte   (rx_data),
    .framing_error (rx_framing_err)
);

// Uart_tx instantiation 	
uart_tx
#(
	.clk_frequency(27), 		// 27 MHz 
	.baud_rate(115200)			// 115200 baud rate
)
TX
(
    .i_clk    	 (clk),
    .i_rst_n   	 (rst_n),
    .data_send 	 (rx_data_latched),
    .tx_valid  	 (tx_valid),
    .ready_tx  	 (tx_ready),
    .o_tx      	 (BL616_UART_TX)
);

// Loopback logic with 1-second delay for LED demonstration
always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        rx_data_latched <= 8'd0;
        tx_valid <= 1'b0;
        delay_counter <= 26'd0;
        delay_active <= 1'b0;
        rx_ack <= 1'b0;
    end
    else
    begin
        // RX acknowledgment logic
        if (rx_done && !rx_ack)
        begin
            rx_data_latched <= rx_data;  	// Latch received data
            rx_ack <= 1'b1;             	// Acknowledge reception
            delay_active <= 1'b1;       	// Start 1-second delay
            delay_counter <= 26'd0;     	// Reset delay counter
        end
        else if (rx_ack && !rx_done)
        begin
            rx_ack <= 1'b0;          		// Clear ack when rx_done goes low
        end
        
        // Delay logic for LED demonstration
        if (delay_active)
        begin
            if (delay_counter < 26'd2_000_000)  
            begin
                delay_counter <= delay_counter + 26'd1;
            end
            else
            begin
                delay_active <= 1'b0;
                tx_valid <= 1'b1;       // Start transmission after delay
            end
        end
        
        // Clear tx_valid when transmission is acknowledged
        if (tx_valid && tx_ready)
        begin
            tx_valid <= 1'b0;
        end
    end
end

// Heartbeat - LED0 1 sec blink
reg [24:0] heart_counter;

always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
		heart_counter <= 0;
		LED0 		  <= 1'b1;
	end
	else if (heart_counter == 27_000_000 - 1)
	begin
		heart_counter <= 0;
		LED0 <= ~LED0;
	end
	else
		heart_counter <= heart_counter + 25'd1;
end

// Rx + Tx activity indicators with distinct timing sequence
// LED1 shows RX activity immediately, LED2 shows TX activity with delay
reg [23:0] led1_counter, led2_counter;
reg rx_done_d;								// For edge detection
wire rx_done_rise = rx_done && ~rx_done_d;
wire tx_accept = tx_valid && tx_ready;

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        led1_counter    <= 0;
        led2_counter    <= 0;
        LED1            <= 1'b1;  // OFF
        LED2            <= 1'b1;  // OFF
		rx_done_d 		<= 1'b0;
    end
    else
    begin
		rx_done_d <= rx_done;
        // LED1 - RX activity (immediate response)
        if (rx_done_rise)
            led1_counter <= 24'd5_400_000;  // ~200ms pulse for clear visibility
        else if (led1_counter > 0)
        begin
            led1_counter <= led1_counter - 1;
            LED1 <= 1'b0;  // ON during countdown
        end
        else
            LED1 <= 1'b1;  // OFF when counter expires
            
        // LED2 - TX activity (triggered when TX accepts the byte)
        if (tx_accept)  // TX handshake active
            led2_counter <= 24'd5_400_000;  // ~200ms pulse
        else if (led2_counter > 0)
        begin
            led2_counter <= led2_counter - 1;
            LED2 <= 1'b0;  // ON during countdown
        end
        else
            LED2 <= 1'b1;  // OFF when counter expires
    end
end

// Framing error detection
// LED3 latches on when an error occurs and stays on until reset
always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
        error_detect <= 1'b0;  // Clear error flag on reset
    else if (rx_framing_err)	
        error_detect <= 1'b1;  // Set error flag when error detected
end

// LED3: indicates errors - ON when parity/framing error detected
always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
        LED3 <= 1'b1;  // OFF (active low)
    else
        LED3 <= error_detect ? 1'b0 : 1'b1;  // ON when error detected
end

// LED4: dedicated reset indicator - ON during reset
assign LED4 = rst_n;

endmodule