// File: tb/uart_test.sv
// Description: Module-based test program with all directed tests

module uart_test #(
  parameter CLKS_PER_BIT = 16
)(
  uart_if vif
);
  
  // Data structures
  typedef struct {
    logic [7:0] data;
    logic       parity_en;
  } exp_tx_t;

  typedef struct {
    logic [7:0] data;
    logic       parity_error;
    logic       framing_error;
  } exp_rx_t;

  exp_tx_t exp_tx_q[$];
  exp_rx_t exp_rx_q[$];

  exp_tx_t obs_tx_q[$];
  exp_rx_t obs_rx_q[$];

  int tx_pass = 0, tx_fail = 0;
  int rx_pass = 0, rx_fail = 0;

  // -----------------------------------------------------
  // Tasks (Driver)
  // -----------------------------------------------------
  task reset_dut();
    $display("[DRIVER] Applying reset...");
    vif.rst_n     <= 1'b0;
    vif.tx_start  <= 1'b0;
    vif.tx_data   <= 8'h00;
    vif.rx_serial <= 1'b1;
    vif.parity_en <= 1'b0;
    repeat (5) @(posedge vif.clk);
    vif.rst_n <= 1'b1;
    repeat (2) @(posedge vif.clk);
    $display("[DRIVER] Reset released.");
  endtask

  task drive_tx(logic [7:0] data, logic par_en);
    $display("[DRIVER] TX start: data=0x%02h parity_en=%0b", data, par_en);
    vif.parity_en <= par_en;
    @(posedge vif.clk);
    vif.tx_data  <= data;
    vif.tx_start <= 1'b1;
    @(posedge vif.clk);
    vif.tx_start <= 1'b0;
    @(posedge vif.tx_done);
    @(posedge vif.clk);
    $display("[DRIVER] TX done for data=0x%02h", data);
  endtask

  function logic calc_even_parity(logic [7:0] data);
    return ^data;
  endfunction

  task drive_rx(logic [7:0] data, logic par_en, logic inj_par_err, logic inj_frame_err);
    logic parity_bit;
    $display("[DRIVER] RX drive: data=0x%02h parity_en=%0b inj_par=%0b inj_frame=%0b",
             data, par_en, inj_par_err, inj_frame_err);

    vif.parity_en <= par_en;
    @(posedge vif.clk);

    vif.rx_serial <= 1'b0;
    repeat (CLKS_PER_BIT) @(posedge vif.clk);

    for (int i = 0; i < 8; i++) begin
      vif.rx_serial <= data[i];
      repeat (CLKS_PER_BIT) @(posedge vif.clk);
    end

    if (par_en) begin
      parity_bit = calc_even_parity(data);
      if (inj_par_err) parity_bit = ~parity_bit;
      vif.rx_serial <= parity_bit;
      repeat (CLKS_PER_BIT) @(posedge vif.clk);
    end

    if (inj_frame_err)
      vif.rx_serial <= 1'b0;
    else
      vif.rx_serial <= 1'b1;
    repeat (CLKS_PER_BIT) @(posedge vif.clk);

    vif.rx_serial <= 1'b1;
    repeat (2) @(posedge vif.clk);
    $display("[DRIVER] RX frame drive complete for data=0x%02h", data);
  endtask

  // -----------------------------------------------------
  // Monitor Tasks
  // -----------------------------------------------------
  task monitor_tx();
    logic [7:0] observed_data;
    logic       observed_parity;
    exp_tx_t obs_tx;

    forever begin
      @(negedge vif.tx_serial);
      $display("[TX_MON] Start bit detected at time %0t", $time);

      repeat (CLKS_PER_BIT / 2) @(posedge vif.clk);
      if (vif.tx_serial !== 1'b0) begin
        $display("[TX_MON] WARNING: False start bit at time %0t", $time);
        continue;
      end

      repeat (CLKS_PER_BIT) @(posedge vif.clk);

      for (int i = 0; i < 8; i++) begin
        observed_data[i] = vif.tx_serial;
        if (i < 7) repeat (CLKS_PER_BIT) @(posedge vif.clk);
      end

      if (vif.parity_en) begin
        repeat (CLKS_PER_BIT) @(posedge vif.clk);
        observed_parity = vif.tx_serial;
      end

      repeat (CLKS_PER_BIT) @(posedge vif.clk);
      if (vif.tx_serial !== 1'b1) begin
        $display("[TX_MON] ERROR: Stop bit not high at time %0t", $time);
      end

      obs_tx.data = observed_data;
      obs_tx.parity_en = vif.parity_en;
      obs_tx_q.push_back(obs_tx);

      $display("[TX_MON] Observed TX frame: data=0x%02h at time %0t", observed_data, $time);
    end
  endtask

  task monitor_rx();
    exp_rx_t obs_rx;
    forever begin
      @(posedge vif.rx_done);
      obs_rx.data = vif.rx_data;
      obs_rx.parity_error = vif.parity_error;
      obs_rx.framing_error = vif.framing_error;
      obs_rx_q.push_back(obs_rx);

      $display("[RX_MON] Observed RX: data=0x%02h par_err=%0b frame_err=%0b at time %0t",
               obs_rx.data, vif.parity_error, vif.framing_error, $time);
    end
  endtask

  // -----------------------------------------------------
  // Scoreboard Tasks
  // -----------------------------------------------------
  task check_tx();
    exp_tx_t exp, obs;
    forever begin
      wait (exp_tx_q.size() > 0 && obs_tx_q.size() > 0);
      exp = exp_tx_q.pop_front();
      obs = obs_tx_q.pop_front();

      if (obs.data === exp.data) begin
        $display("[SCOREBOARD] TX PASS: expected=0x%02h observed=0x%02h", exp.data, obs.data);
        tx_pass++;
      end else begin
        $display("[SCOREBOARD] TX FAIL: expected=0x%02h observed=0x%02h", exp.data, obs.data);
        tx_fail++;
      end
    end
  endtask

  task check_rx();
    exp_rx_t exp, obs;
    forever begin
      wait (exp_rx_q.size() > 0 && obs_rx_q.size() > 0);
      exp = exp_rx_q.pop_front();
      obs = obs_rx_q.pop_front();

      if (obs.data === exp.data && 
          obs.parity_error === exp.parity_error && 
          obs.framing_error === exp.framing_error) begin
        $display("[SCOREBOARD] RX PASS: data=0x%02h par_err=%0b frm_err=%0b", obs.data, obs.parity_error, obs.framing_error);
        rx_pass++;
      end else begin
        $display("[SCOREBOARD] RX FAIL: exp={0x%02h, %0b, %0b} obs={0x%02h, %0b, %0b}", 
                 exp.data, exp.parity_error, exp.framing_error, 
                 obs.data, obs.parity_error, obs.framing_error);
        rx_fail++;
      end
    end
  endtask

  function void report();
    $display("==================================================");
    $display("           SCOREBOARD FINAL REPORT");
    $display("==================================================");
    $display("  TX: %0d PASS, %0d FAIL", tx_pass, tx_fail);
    $display("  RX: %0d PASS, %0d FAIL", rx_pass, rx_fail);
    $display("==================================================");
  endfunction

  // -----------------------------------------------------
  // Test Sequence
  // -----------------------------------------------------

  task automatic send_tx(logic [7:0] data, logic par_en);
    exp_tx_t exp;
    exp.data = data;
    exp.parity_en = par_en;
    exp_tx_q.push_back(exp);
    drive_tx(data, par_en);
  endtask

  task automatic send_rx(logic [7:0] data, logic par_en, logic inj_par_err = 0, logic inj_frame_err = 0);
    exp_rx_t exp;
    exp.data = data;
    exp.parity_error = (par_en && inj_par_err) ? 1'b1 : 1'b0;
    exp.framing_error = inj_frame_err;
    exp_rx_q.push_back(exp);
    drive_rx(data, par_en, inj_par_err, inj_frame_err);
    @(posedge vif.rx_done);
    @(posedge vif.clk);
  endtask

  initial begin
    // Start concurrent processes
    fork
      monitor_tx();
      monitor_rx();
      check_tx();
      check_rx();
    join_none

    $display("\n===== T1: RESET TEST =====");
    reset_dut();
    $display("T1: Reset test complete.\n");

    $display("\n===== T2: BASIC TX TEST =====");
    send_tx(8'h55, 1'b0);
    send_tx(8'hA3, 1'b0);
    $display("T2: Basic TX test complete.\n");

    $display("\n===== T3: BASIC RX TEST =====");
    send_rx(8'hA3, 1'b0);
    send_rx(8'h55, 1'b0);
    $display("T3: Basic RX test complete.\n");

    $display("\n===== T4: MULTIPLE TX TEST =====");
    send_tx(8'h00, 1'b0);
    send_tx(8'hFF, 1'b0);
    send_tx(8'h55, 1'b0);
    send_tx(8'hAA, 1'b0);
    $display("T4: Multiple TX test complete.\n");

    $display("\n===== T5: MULTIPLE RX TEST =====");
    send_rx(8'h00, 1'b0);
    send_rx(8'hFF, 1'b0);
    send_rx(8'h55, 1'b0);
    send_rx(8'hAA, 1'b0);
    $display("T5: Multiple RX test complete.\n");

    $display("\n===== T6: TX WITH PARITY TEST =====");
    send_tx(8'h55, 1'b1);
    send_tx(8'hA3, 1'b1);
    $display("T6: TX parity test complete.\n");

    $display("\n===== T7: RX GOOD PARITY TEST =====");
    send_rx(8'h55, 1'b1, 0, 0);
    send_rx(8'hA3, 1'b1, 0, 0);
    $display("T7: RX good parity test complete.\n");

    $display("\n===== T8: PARITY ERROR TEST =====");
    send_rx(8'h55, 1'b1, 1, 0);
    $display("T8: Parity error test complete.\n");

    $display("\n===== T9: FRAMING ERROR TEST =====");
    send_rx(8'hA3, 1'b0, 0, 1);
    $display("T9: Framing error test complete.\n");

    $display("\n===== T10: BACK-TO-BACK TX TEST =====");
    send_tx(8'h11, 1'b0);
    send_tx(8'h22, 1'b0);
    send_tx(8'h33, 1'b0);
    $display("T10: Back-to-back TX test complete.\n");

    $display("\n===== T11: LOOPBACK TEST =====");
    begin
      logic [7:0] lb_data = 8'hBC;
      exp_rx_t exp_rx;
      exp_tx_t exp_tx;

      exp_rx.data = lb_data;
      exp_rx.parity_error = 0;
      exp_rx.framing_error = 0;
      exp_rx_q.push_back(exp_rx);

      vif.parity_en <= 1'b0;
      @(posedge vif.clk);

      fork
        begin // TX side
          exp_tx.data = lb_data;
          exp_tx.parity_en = 1'b0;
          exp_tx_q.push_back(exp_tx);
          drive_tx(lb_data, 1'b0);
        end
        begin // Loopback wire
          forever begin
            @(posedge vif.clk);
            vif.rx_serial <= vif.tx_serial;
          end
        end
      join_any
      disable fork;
      
      @(posedge vif.rx_done);
      @(posedge vif.clk);
      vif.rx_serial <= 1'b1;
      @(posedge vif.clk);
    end
    $display("T11: Loopback test complete.\n");

    $display("\n===== T12: RANDOM TX TEST =====");
    for (int i = 0; i < 20; i++) begin
      logic [7:0] rand_data = $random;
      send_tx(rand_data, 1'b0);
    end
    $display("T12: Random TX test complete.\n");

    $display("\n===== T13: RANDOM RX TEST =====");
    for (int i = 0; i < 20; i++) begin
      logic [7:0] rand_data = $random;
      send_rx(rand_data, 1'b0);
    end
    $display("T13: Random RX test complete.\n");

    $display("\n===== T14: PARITY ERROR THEN VALID =====");
    send_rx(8'h77, 1'b1, 1, 0);
    send_rx(8'h88, 1'b1, 0, 0);
    $display("T14: Parity error recovery test complete.\n");

    $display("\n===== T15: FRAMING ERROR THEN VALID =====");
    send_rx(8'h99, 1'b0, 0, 1);
    send_rx(8'hBB, 1'b0, 0, 0);
    $display("T15: Framing error recovery test complete.\n");

    repeat (100) @(posedge vif.clk);
    report();

    $display("\n*** SIMULATION COMPLETE ***\n");
    $finish;
  end

endmodule
