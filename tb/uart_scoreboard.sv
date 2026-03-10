// File: tb/uart_scoreboard.sv
// Description: Compares expected and observed UART transactions

class uart_scoreboard;

  // Expected transaction queues (populated by test)
  mailbox #(uart_txn) exp_tx_mbx;
  mailbox #(uart_txn) exp_rx_mbx;

  // Observed transaction mailboxes (from monitor)
  mailbox #(uart_txn) obs_tx_mbx;
  mailbox #(uart_txn) obs_rx_mbx;

  // Counters
  int tx_pass, tx_fail;
  int rx_pass, rx_fail;

  function new();
    exp_tx_mbx = new();
    exp_rx_mbx = new();
    tx_pass = 0; tx_fail = 0;
    rx_pass = 0; rx_fail = 0;
  endfunction

  // Connect observed mailboxes from monitor
  function void connect(mailbox #(uart_txn) obs_tx, mailbox #(uart_txn) obs_rx);
    this.obs_tx_mbx = obs_tx;
    this.obs_rx_mbx = obs_rx;
  endfunction

  // ----------------------------------------------------------
  // TX Checker
  // ----------------------------------------------------------
  task check_tx();
    uart_txn exp_txn, obs_txn;
    forever begin
      exp_tx_mbx.get(exp_txn);
      obs_tx_mbx.get(obs_txn);

      if (obs_txn.data === exp_txn.data) begin
        $display("[SCOREBOARD] TX PASS: expected=0x%02h observed=0x%02h", exp_txn.data, obs_txn.data);
        tx_pass++;
      end else begin
        $display("[SCOREBOARD] TX FAIL: expected=0x%02h observed=0x%02h", exp_txn.data, obs_txn.data);
        tx_fail++;
      end
    end
  endtask

  // ----------------------------------------------------------
  // RX Checker
  // ----------------------------------------------------------
  task check_rx();
    uart_txn exp_txn, obs_txn;
    forever begin
      exp_rx_mbx.get(exp_txn);
      obs_rx_mbx.get(obs_txn);

      // Check data
      if (obs_txn.data === exp_txn.expected_rx_data) begin
        $display("[SCOREBOARD] RX DATA PASS: expected=0x%02h observed=0x%02h",
                 exp_txn.expected_rx_data, obs_txn.data);
        rx_pass++;
      end else begin
        $display("[SCOREBOARD] RX DATA FAIL: expected=0x%02h observed=0x%02h",
                 exp_txn.expected_rx_data, obs_txn.data);
        rx_fail++;
      end

      // Check parity_error flag
      if (obs_txn.expected_parity_error !== exp_txn.expected_parity_error) begin
        $display("[SCOREBOARD] RX PARITY_ERROR FAIL: expected=%0b observed=%0b",
                 exp_txn.expected_parity_error, obs_txn.expected_parity_error);
        rx_fail++;
      end

      // Check framing_error flag
      if (obs_txn.expected_framing_error !== exp_txn.expected_framing_error) begin
        $display("[SCOREBOARD] RX FRAMING_ERROR FAIL: expected=%0b observed=%0b",
                 exp_txn.expected_framing_error, obs_txn.expected_framing_error);
        rx_fail++;
      end
    end
  endtask

  // Run both checkers
  task run();
    fork
      check_tx();
      check_rx();
    join_none
  endtask

  // Final report
  function void report();
    $display("==================================================");
    $display("           SCOREBOARD FINAL REPORT");
    $display("==================================================");
    $display("  TX: %0d PASS, %0d FAIL", tx_pass, tx_fail);
    $display("  RX: %0d PASS, %0d FAIL", rx_pass, rx_fail);
    $display("==================================================");
    if (tx_fail == 0 && rx_fail == 0)
      $display("  *** ALL TESTS PASSED ***");
    else
      $display("  *** SOME TESTS FAILED ***");
    $display("==================================================");
  endfunction

endclass
