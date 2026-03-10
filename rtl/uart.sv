// File: rtl/uart.sv
// Description: UART Transmitter and Receiver
// Parameters:  CLKS_PER_BIT - clock cycles per serial bit

module uart #(
  parameter CLKS_PER_BIT = 16
)(
  input  logic       clk,
  input  logic       rst_n,

  // TX interface
  input  logic       tx_start,
  input  logic [7:0] tx_data,
  output logic       tx_serial,
  output logic       tx_busy,
  output logic       tx_done,

  // RX interface
  input  logic       rx_serial,
  output logic [7:0] rx_data,
  output logic       rx_done,

  // Control
  input  logic       parity_en,

  // Error flags
  output logic       parity_error,
  output logic       framing_error
);

  // ============================================================
  // TX Logic
  // ============================================================
  typedef enum logic [2:0] {
    TX_IDLE   = 3'd0,
    TX_START  = 3'd1,
    TX_DATA   = 3'd2,
    TX_PARITY = 3'd3,
    TX_STOP   = 3'd4
  } tx_state_t;

  tx_state_t tx_state;
  logic [$clog2(CLKS_PER_BIT)-1:0] tx_clk_cnt;
  logic [2:0]  tx_bit_idx;
  logic [7:0]  tx_shift;
  logic        tx_parity_bit;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      tx_state      <= TX_IDLE;
      tx_serial     <= 1'b1;
      tx_busy       <= 1'b0;
      tx_done       <= 1'b0;
      tx_clk_cnt    <= '0;
      tx_bit_idx    <= '0;
      tx_shift      <= '0;
      tx_parity_bit <= 1'b0;
    end else begin
      tx_done <= 1'b0; // default: pulse for 1 cycle only

      case (tx_state)
        TX_IDLE: begin
          tx_serial <= 1'b1;
          tx_busy   <= 1'b0;
          tx_clk_cnt <= '0;
          tx_bit_idx <= '0;
          if (tx_start) begin
            tx_shift      <= tx_data;
            tx_busy       <= 1'b1;
            tx_parity_bit <= 1'b0;
            tx_state      <= TX_START;
          end
        end

        TX_START: begin
          tx_serial <= 1'b0;
          if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
            tx_clk_cnt <= '0;
            tx_state   <= TX_DATA;
          end else begin
            tx_clk_cnt <= tx_clk_cnt + 1;
          end
        end

        TX_DATA: begin
          tx_serial <= tx_shift[tx_bit_idx];
          if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
            tx_clk_cnt    <= '0;
            tx_parity_bit <= tx_parity_bit ^ tx_shift[tx_bit_idx];
            if (tx_bit_idx == 3'd7) begin
              tx_bit_idx <= '0;
              tx_state   <= parity_en ? TX_PARITY : TX_STOP;
            end else begin
              tx_bit_idx <= tx_bit_idx + 1;
            end
          end else begin
            tx_clk_cnt <= tx_clk_cnt + 1;
          end
        end

        TX_PARITY: begin
          tx_serial <= tx_parity_bit; // even parity
          if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
            tx_clk_cnt <= '0;
            tx_state   <= TX_STOP;
          end else begin
            tx_clk_cnt <= tx_clk_cnt + 1;
          end
        end

        TX_STOP: begin
          tx_serial <= 1'b1;
          if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
            tx_clk_cnt <= '0;
            tx_done    <= 1'b1;
            tx_state   <= TX_IDLE;
          end else begin
            tx_clk_cnt <= tx_clk_cnt + 1;
          end
        end

        default: tx_state <= TX_IDLE;
      endcase
    end
  end

  // ============================================================
  // RX Logic
  // ============================================================
  typedef enum logic [2:0] {
    RX_IDLE   = 3'd0,
    RX_START  = 3'd1,
    RX_DATA   = 3'd2,
    RX_PARITY = 3'd3,
    RX_STOP   = 3'd4
  } rx_state_t;

  rx_state_t rx_state;
  logic [$clog2(CLKS_PER_BIT)-1:0] rx_clk_cnt;
  logic [2:0]  rx_bit_idx;
  logic [7:0]  rx_shift;
  logic        rx_parity_calc;
  logic        parity_err_reg;

  // Double-flop synchronizer for rx_serial
  logic rx_serial_ff1, rx_serial_ff2;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      rx_serial_ff1 <= 1'b1;
      rx_serial_ff2 <= 1'b1;
    end else begin
      rx_serial_ff1 <= rx_serial;
      rx_serial_ff2 <= rx_serial_ff1;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      rx_state       <= RX_IDLE;
      rx_data        <= 8'd0;
      rx_done        <= 1'b0;
      rx_clk_cnt     <= '0;
      rx_bit_idx     <= '0;
      rx_shift       <= '0;
      rx_parity_calc <= 1'b0;
      parity_error   <= 1'b0;
      framing_error  <= 1'b0;
      parity_err_reg <= 1'b0;
    end else begin
      rx_done       <= 1'b0; // default: pulse for 1 cycle only
      parity_error  <= 1'b0;
      framing_error <= 1'b0;

      case (rx_state)
        RX_IDLE: begin
          rx_clk_cnt     <= '0;
          rx_bit_idx     <= '0;
          rx_parity_calc <= 1'b0;
          parity_err_reg <= 1'b0;
          if (rx_serial_ff2 == 1'b0) begin // falling edge detected
            rx_state <= RX_START;
          end
        end

        RX_START: begin
          // Sample at mid-bit of start
          if (rx_clk_cnt == (CLKS_PER_BIT - 1) / 2) begin
            if (rx_serial_ff2 == 1'b0) begin
              // Valid start bit
              rx_clk_cnt <= '0;
              rx_state   <= RX_DATA;
            end else begin
              // False start
              rx_state <= RX_IDLE;
            end
          end else begin
            rx_clk_cnt <= rx_clk_cnt + 1;
          end
        end

        RX_DATA: begin
          if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
            rx_clk_cnt <= '0;
            rx_shift[rx_bit_idx] <= rx_serial_ff2;
            rx_parity_calc <= rx_parity_calc ^ rx_serial_ff2;
            if (rx_bit_idx == 3'd7) begin
              rx_bit_idx <= '0;
              rx_state   <= parity_en ? RX_PARITY : RX_STOP;
            end else begin
              rx_bit_idx <= rx_bit_idx + 1;
            end
          end else begin
            rx_clk_cnt <= rx_clk_cnt + 1;
          end
        end

        RX_PARITY: begin
          if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
            rx_clk_cnt <= '0;
            // Even parity: all data bits XOR should == parity bit
            if (rx_parity_calc != rx_serial_ff2) begin
              parity_err_reg <= 1'b1;
            end else begin
              parity_err_reg <= 1'b0;
            end
            rx_state <= RX_STOP;
          end else begin
            rx_clk_cnt <= rx_clk_cnt + 1;
          end
        end

        RX_STOP: begin
          if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
            rx_clk_cnt <= '0;
            if (rx_serial_ff2 != 1'b1) begin
              framing_error <= 1'b1;
            end
            if (parity_err_reg) begin
              parity_error <= 1'b1;
            end
            rx_data  <= rx_shift;
            rx_done  <= 1'b1;
            rx_state <= RX_IDLE;
          end else begin
            rx_clk_cnt <= rx_clk_cnt + 1;
          end
        end

        default: rx_state <= RX_IDLE;
      endcase
    end
  end

endmodule
