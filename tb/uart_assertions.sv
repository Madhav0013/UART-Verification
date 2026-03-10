// File: tb/uart_assertions.sv
module uart_assertions #(
  parameter CLKS_PER_BIT = 16
)(
  input logic       clk,
  input logic       rst_n,
  input logic       tx_serial,
  input logic       tx_busy,
  input logic       tx_done,
  input logic       rx_done,
  input logic       parity_en,
  input logic       parity_error,
  input logic       framing_error,
  input logic [2:0] tx_state,
  input logic [2:0] rx_state
);

  localparam TX_IDLE  = 3'd0;
  localparam TX_START = 3'd1;

  always_ff @(posedge clk) begin
    if (rst_n) begin
      // A1
      if (tx_state == TX_IDLE && tx_serial !== 1'b1)
        $display("[ASSERT A1 ERROR] tx_serial not high during TX IDLE at time %0t", $time);
      
      // A2
      if (tx_state == TX_START && tx_serial !== 1'b0)
        $display("[ASSERT A2 ERROR] tx_serial not low during TX START at time %0t", $time);
      
      // A6
      if (tx_state != TX_IDLE && tx_busy !== 1'b1)
        $display("[ASSERT A6 ERROR] tx_busy not high during active TX at time %0t", $time);

      // A7
      if (parity_error && !parity_en)
        $display("[ASSERT A7 ERROR] parity_error asserted but parity_en=0 at time %0t", $time);
    end
  end

  // Pulse checks (A3, A4) requires storing previous value
  logic tx_done_prev, rx_done_prev;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      tx_done_prev <= 1'b0;
      rx_done_prev <= 1'b0;
    end else begin
      if (tx_done_prev && tx_done)
        $display("[ASSERT A3 ERROR] tx_done was not a single-cycle pulse at time %0t", $time);
      if (rx_done_prev && rx_done)
        $display("[ASSERT A4 ERROR] rx_done was not a single-cycle pulse at time %0t", $time);
      
      tx_done_prev <= tx_done;
      rx_done_prev <= rx_done;
    end
  end

  // Post reset checks (A5, A8)
  logic rst_n_prev;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      rst_n_prev <= 1'b0;
    end else begin
      rst_n_prev <= rst_n;
      if (!rst_n_prev && rst_n) begin
        // Just came out of reset
        if (tx_serial !== 1'b1)
          $display("[ASSERT A5 ERROR] tx_serial not high after reset at time %0t", $time);
        if (parity_error || framing_error)
          $display("[ASSERT A8 ERROR] Error flags present after reset at time %0t", $time);
      end
    end
  end

endmodule
