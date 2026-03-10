// File: tb/uart_driver.sv
// Description: Drives TX and RX stimulus onto the DUT

class uart_driver;

  virtual uart_if.DRV vif;
  int CLKS_PER_BIT;

  function new(virtual uart_if.DRV vif, int clks_per_bit = 16);
    this.vif = vif;
    this.CLKS_PER_BIT = clks_per_bit;
  endfunction

  // ----------------------------------------------------------
  // Reset DUT
  // ----------------------------------------------------------
  task reset_dut();
    $display("[DRIVER] Applying reset...");
    vif.drv_cb.rst_n     <= 1'b0;
    vif.drv_cb.tx_start  <= 1'b0;
    vif.drv_cb.tx_data   <= 8'h00;
    vif.drv_cb.rx_serial <= 1'b1; // idle high
    vif.drv_cb.parity_en <= 1'b0;
    repeat (5) @(vif.drv_cb);
    vif.drv_cb.rst_n <= 1'b1;
    repeat (2) @(vif.drv_cb);
    $display("[DRIVER] Reset released.");
  endtask

  // ----------------------------------------------------------
  // Drive a TX transaction (tell DUT to transmit)
  // ----------------------------------------------------------
  task drive_tx(uart_txn txn);
    $display("[DRIVER] TX start: data=0x%02h parity_en=%0b", txn.data, txn.parity_en);
    vif.drv_cb.parity_en <= txn.parity_en;
    @(vif.drv_cb);
    vif.drv_cb.tx_data  <= txn.data;
    vif.drv_cb.tx_start <= 1'b1;
    @(vif.drv_cb);
    vif.drv_cb.tx_start <= 1'b0;
    // Wait for tx_done
    @(posedge vif.drv_cb.tx_done);
    @(vif.drv_cb); // one extra cycle
    $display("[DRIVER] TX done for data=0x%02h", txn.data);
  endtask

  // ----------------------------------------------------------
  // Drive an RX transaction (send serial frame into DUT RX)
  // ----------------------------------------------------------
  task drive_rx(uart_txn txn);
    logic parity_bit;
    $display("[DRIVER] RX drive: data=0x%02h parity_en=%0b inj_par=%0b inj_frame=%0b",
             txn.data, txn.parity_en, txn.inject_parity_error, txn.inject_framing_error);

    vif.drv_cb.parity_en <= txn.parity_en;
    @(vif.drv_cb);

    // START bit
    vif.drv_cb.rx_serial <= 1'b0;
    repeat (CLKS_PER_BIT) @(vif.drv_cb);

    // DATA bits (LSB first)
    for (int i = 0; i < 8; i++) begin
      vif.drv_cb.rx_serial <= txn.data[i];
      repeat (CLKS_PER_BIT) @(vif.drv_cb);
    end

    // PARITY bit (if enabled)
    if (txn.parity_en) begin
      parity_bit = txn.calc_even_parity();
      if (txn.inject_parity_error) parity_bit = ~parity_bit;
      vif.drv_cb.rx_serial <= parity_bit;
      repeat (CLKS_PER_BIT) @(vif.drv_cb);
    end

    // STOP bit
    if (txn.inject_framing_error)
      vif.drv_cb.rx_serial <= 1'b0; // bad stop bit
    else
      vif.drv_cb.rx_serial <= 1'b1;
    repeat (CLKS_PER_BIT) @(vif.drv_cb);

    // Return to idle
    vif.drv_cb.rx_serial <= 1'b1;
    repeat (2) @(vif.drv_cb);

    $display("[DRIVER] RX frame drive complete for data=0x%02h", txn.data);
  endtask

endclass
