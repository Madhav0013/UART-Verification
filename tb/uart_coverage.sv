// File: tb/uart_coverage.sv
// Description: Functional coverage for UART verification

class uart_coverage;

  // Coverage signals (sampled from interface)
  logic [7:0] tx_data_cov;
  logic [7:0] rx_data_cov;
  logic       parity_en_cov;
  logic       parity_error_cov;
  logic       framing_error_cov;
  logic       tx_done_cov;
  logic       rx_done_cov;

  // Covergroup: TX data patterns
  covergroup cg_tx_data;
    cp_tx_data: coverpoint tx_data_cov {
      bins zero     = {8'h00};
      bins all_ones = {8'hFF};
      bins alt_01   = {8'h55};
      bins alt_10   = {8'hAA};
      bins low      = {[8'h01 : 8'h7F]};
      bins high     = {[8'h80 : 8'hFE]};
    }
    cp_parity_en: coverpoint parity_en_cov {
      bins off = {0};
      bins on  = {1};
    }
    cx_data_parity: cross cp_tx_data, cp_parity_en;
  endgroup

  // Covergroup: RX data patterns
  covergroup cg_rx_data;
    cp_rx_data: coverpoint rx_data_cov {
      bins zero     = {8'h00};
      bins all_ones = {8'hFF};
      bins alt_01   = {8'h55};
      bins alt_10   = {8'hAA};
      bins low      = {[8'h01 : 8'h7F]};
      bins high     = {[8'h80 : 8'hFE]};
    }
  endgroup

  // Covergroup: Error scenarios
  covergroup cg_errors;
    cp_parity_error: coverpoint parity_error_cov {
      bins no_err  = {0};
      bins has_err = {1};
    }
    cp_framing_error: coverpoint framing_error_cov {
      bins no_err  = {0};
      bins has_err = {1};
    }
  endgroup

  function new();
    cg_tx_data = new();
    cg_rx_data = new();
    cg_errors  = new();
  endfunction

  // Call after each TX transaction
  function void sample_tx(logic [7:0] data, logic par_en);
    tx_data_cov   = data;
    parity_en_cov = par_en;
    cg_tx_data.sample();
  endfunction

  // Call after each RX transaction
  function void sample_rx(logic [7:0] data, logic par_err, logic frame_err);
    rx_data_cov       = data;
    parity_error_cov  = par_err;
    framing_error_cov = frame_err;
    cg_rx_data.sample();
    cg_errors.sample();
  endfunction

  // Report coverage
  function void report();
    $display("==================================================");
    $display("         FUNCTIONAL COVERAGE REPORT");
    $display("==================================================");
    $display("  TX Data Coverage:  %.1f%%", cg_tx_data.get_coverage());
    $display("  RX Data Coverage:  %.1f%%", cg_rx_data.get_coverage());
    $display("  Error Coverage:    %.1f%%", cg_errors.get_coverage());
    $display("==================================================");
  endfunction

endclass
