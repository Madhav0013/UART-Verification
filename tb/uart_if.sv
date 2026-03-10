// File: tb/uart_if.sv
// Description: Interface for UART DUT signals

interface uart_if (input logic clk);
  logic       rst_n;
  logic       tx_start;
  logic [7:0] tx_data;
  logic       tx_serial;
  logic       tx_busy;
  logic       tx_done;
  logic       rx_serial;
  logic [7:0] rx_data;
  logic       rx_done;
  logic       parity_en;
  logic       parity_error;
  logic       framing_error;
endinterface
