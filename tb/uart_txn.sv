// File: tb/uart_txn.sv
// Description: UART transaction class

class uart_txn;

  // Transaction type
  typedef enum {TX, RX} txn_type_t;
  txn_type_t txn_type;

  // Data
  rand logic [7:0] data;

  // Configuration
  logic parity_en;

  // Error injection (for RX stimulus)
  logic inject_parity_error;
  logic inject_framing_error;

  // Expected results (filled by test or reference model)
  logic [7:0] expected_rx_data;
  logic       expected_parity_error;
  logic       expected_framing_error;

  // Constructor
  function new(txn_type_t t = TX);
    txn_type             = t;
    data                 = 8'h00;
    parity_en            = 1'b0;
    inject_parity_error  = 1'b0;
    inject_framing_error = 1'b0;
    expected_rx_data     = 8'h00;
    expected_parity_error  = 1'b0;
    expected_framing_error = 1'b0;
  endfunction

  // Compute even parity
  function logic calc_even_parity();
    return ^data;
  endfunction

  // Display
  function void display(string tag = "TXN");
    $display("[%s] type=%s data=0x%02h parity_en=%0b inj_par_err=%0b inj_frame_err=%0b",
             tag, txn_type.name(), data, parity_en, inject_parity_error, inject_framing_error);
  endfunction

  // Copy
  function uart_txn copy();
    uart_txn c = new(this.txn_type);
    c.data                  = this.data;
    c.parity_en             = this.parity_en;
    c.inject_parity_error   = this.inject_parity_error;
    c.inject_framing_error  = this.inject_framing_error;
    c.expected_rx_data      = this.expected_rx_data;
    c.expected_parity_error = this.expected_parity_error;
    c.expected_framing_error= this.expected_framing_error;
    return c;
  endfunction

endclass
