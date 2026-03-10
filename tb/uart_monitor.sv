// File: tb/uart_monitor.sv
// Description: Monitors TX serial output and RX outputs

class uart_monitor;

  virtual uart_if.MON vif;
  int CLKS_PER_BIT;

  // Mailboxes to send observed transactions to scoreboard
  mailbox #(uart_txn) tx_mbx;
  mailbox #(uart_txn) rx_mbx;

  function new(virtual uart_if.MON vif, int clks_per_bit = 16);
    this.vif = vif;
    this.CLKS_PER_BIT = clks_per_bit;
    tx_mbx = new();
    rx_mbx = new();
  endfunction

  // ----------------------------------------------------------
  // TX Monitor: watch tx_serial and reconstruct the frame
  // ----------------------------------------------------------
  task monitor_tx();
    logic [7:0] observed_data;
    logic       observed_parity;

    forever begin
      uart_txn obs_txn;

      // Wait for start bit (tx_serial going low)
      @(negedge vif.mon_cb.tx_serial);
      $display("[TX_MON] Start bit detected at time %0t", $time);

      // Wait to mid-bit of start (verify it's still low)
      repeat (CLKS_PER_BIT / 2) @(vif.mon_cb);
      if (vif.mon_cb.tx_serial !== 1'b0) begin
        $display("[TX_MON] WARNING: False start bit at time %0t", $time);
        continue;
      end

      // Move to first data bit mid-point
      repeat (CLKS_PER_BIT) @(vif.mon_cb);

      // Sample 8 data bits
      for (int i = 0; i < 8; i++) begin
        observed_data[i] = vif.mon_cb.tx_serial;
        if (i < 7) repeat (CLKS_PER_BIT) @(vif.mon_cb);
      end

      // If parity enabled, sample parity bit
      if (vif.mon_cb.parity_en) begin
        repeat (CLKS_PER_BIT) @(vif.mon_cb);
        observed_parity = vif.mon_cb.tx_serial;
      end

      // Move to stop bit
      repeat (CLKS_PER_BIT) @(vif.mon_cb);

      // Check stop bit
      if (vif.mon_cb.tx_serial !== 1'b1) begin
        $display("[TX_MON] ERROR: Stop bit not high at time %0t", $time);
      end

      obs_txn = new(uart_txn::TX);
      obs_txn.data = observed_data;
      obs_txn.parity_en = vif.mon_cb.parity_en;
      tx_mbx.put(obs_txn);

      $display("[TX_MON] Observed TX frame: data=0x%02h at time %0t", observed_data, $time);
    end
  endtask

  // ----------------------------------------------------------
  // RX Monitor: watch rx_done and capture outputs
  // ----------------------------------------------------------
  task monitor_rx();
    forever begin
      uart_txn obs_txn;

      @(posedge vif.mon_cb.rx_done);
      obs_txn = new(uart_txn::RX);
      obs_txn.data                    = vif.mon_cb.rx_data;
      obs_txn.expected_parity_error   = vif.mon_cb.parity_error;
      obs_txn.expected_framing_error  = vif.mon_cb.framing_error;
      rx_mbx.put(obs_txn);

      $display("[RX_MON] Observed RX: data=0x%02h par_err=%0b frame_err=%0b at time %0t",
               obs_txn.data, vif.mon_cb.parity_error, vif.mon_cb.framing_error, $time);
    end
  endtask

  // Start both monitors
  task run();
    fork
      monitor_tx();
      monitor_rx();
    join_none
  endtask

endclass
