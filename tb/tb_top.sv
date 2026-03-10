// File: tb/tb_top.sv
// Description: Fully module-based testbench for Icarus Verilog compatibility

`timescale 1ns/1ps

module tb_top;

  parameter CLKS_PER_BIT = 16;
  parameter CLK_PERIOD   = 10;

  logic       clk;
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

  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  uart #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
  ) dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .tx_start      (tx_start),
    .tx_data       (tx_data),
    .tx_serial     (tx_serial),
    .tx_busy       (tx_busy),
    .tx_done       (tx_done),
    .rx_serial     (rx_serial),
    .rx_data       (rx_data),
    .rx_done       (rx_done),
    .parity_en     (parity_en),
    .parity_error  (parity_error),
    .framing_error (framing_error)
  );

  uart_assertions #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
  ) u_assertions (
    .clk           (clk),
    .rst_n         (rst_n),
    .tx_serial     (tx_serial),
    .tx_busy       (tx_busy),
    .tx_done       (tx_done),
    .rx_done       (rx_done),
    .parity_en     (parity_en),
    .parity_error  (parity_error),
    .framing_error (framing_error),
    .tx_state      (dut.tx_state),
    .rx_state      (dut.rx_state)
  );

  // Queues to mimic mailboxes
  logic [7:0] exp_tx_data_q[$];
  logic       exp_tx_par_q[$];
  logic [7:0] exp_rx_data_q[$];
  logic       exp_rx_par_err_q[$];
  logic       exp_rx_frm_err_q[$];

  logic [7:0] obs_tx_data_q[$];
  logic       obs_tx_par_q[$];
  logic [7:0] obs_rx_data_q[$];
  logic       obs_rx_par_err_q[$];
  logic       obs_rx_frm_err_q[$];

  int tx_pass = 0, tx_fail = 0;
  int rx_pass = 0, rx_fail = 0;

  // -----------------------------------------------------
  // Tasks (Driver)
  // -----------------------------------------------------
  task reset_dut();
    begin
      $display("[DRIVER] Applying reset...");
      rst_n     <= 1'b0;
      tx_start  <= 1'b0;
      tx_data   <= 8'h00;
      rx_serial <= 1'b1;
      parity_en <= 1'b0;
      repeat (5) @(posedge clk);
      rst_n <= 1'b1;
      repeat (2) @(posedge clk);
      $display("[DRIVER] Reset released.");
    end
  endtask

  task drive_tx(input logic [7:0] data, input logic par_en);
    begin
      $display("[DRIVER] TX start: data=0x%02h parity_en=%0b", data, par_en);
      parity_en <= par_en;
      @(posedge clk);
      tx_data  <= data;
      tx_start <= 1'b1;
      @(posedge clk);
      tx_start <= 1'b0;
      @(posedge tx_done);
      @(posedge clk);
      $display("[DRIVER] TX done for data=0x%02h", data);
    end
  endtask

  function logic calc_even_parity(input logic [7:0] data);
    begin
      calc_even_parity = ^data;
    end
  endfunction

  task drive_rx(input logic [7:0] data, input logic par_en, input logic inj_par_err, input logic inj_frame_err);
    logic parity_bit;
    integer i;
    begin
      $display("[DRIVER] RX drive: data=0x%02h parity_en=%0b inj_par=%0b inj_frame=%0b",
               data, par_en, inj_par_err, inj_frame_err);

      parity_en <= par_en;
      @(posedge clk);

      rx_serial <= 1'b0;
      repeat (CLKS_PER_BIT) @(posedge clk);

      for (i = 0; i < 8; i = i + 1) begin
        rx_serial <= data[i];
        repeat (CLKS_PER_BIT) @(posedge clk);
      end

      if (par_en) begin
        parity_bit = calc_even_parity(data);
        if (inj_par_err) parity_bit = ~parity_bit;
        rx_serial <= parity_bit;
        repeat (CLKS_PER_BIT) @(posedge clk);
      end

      if (inj_frame_err)
        rx_serial <= 1'b0;
      else
        rx_serial <= 1'b1;
      repeat (CLKS_PER_BIT) @(posedge clk);

      rx_serial <= 1'b1;
      repeat (2) @(posedge clk);
      $display("[DRIVER] RX frame drive complete for data=0x%02h", data);
    end
  endtask

  // -----------------------------------------------------
  // Monitor Tasks
  // -----------------------------------------------------
  task monitor_tx();
    logic [7:0] observed_data;
    logic       observed_parity;
    integer i;
    begin
      forever begin
        @(negedge tx_serial);
        $display("[TX_MON] Start bit detected at time %0t", $time);

        repeat (CLKS_PER_BIT / 2) @(posedge clk);
        if (tx_serial !== 1'b0) begin
          $display("[TX_MON] WARNING: False start bit at time %0t", $time);
        end else begin
          repeat (CLKS_PER_BIT) @(posedge clk);

          for (i = 0; i < 8; i = i + 1) begin
            observed_data[i] = tx_serial;
            if (i < 7) repeat (CLKS_PER_BIT) @(posedge clk);
          end

          if (parity_en) begin
            repeat (CLKS_PER_BIT) @(posedge clk);
            observed_parity = tx_serial;
          end

          repeat (CLKS_PER_BIT) @(posedge clk);
          if (tx_serial !== 1'b1) begin
            $display("[TX_MON] ERROR: Stop bit not high at time %0t", $time);
          end

          obs_tx_data_q.push_back(observed_data);
          obs_tx_par_q.push_back(parity_en);

          $display("[TX_MON] Observed TX frame: data=0x%02h at time %0t", observed_data, $time);
        end
      end
    end
  endtask

  task monitor_rx();
    begin
      forever begin
        @(posedge rx_done);
        obs_rx_data_q.push_back(rx_data);
        obs_rx_par_err_q.push_back(parity_error);
        obs_rx_frm_err_q.push_back(framing_error);

        $display("[RX_MON] Observed RX: data=0x%02h par_err=%0b frame_err=%0b at time %0t",
                 rx_data, parity_error, framing_error, $time);
      end
    end
  endtask

  // -----------------------------------------------------
  // Scoreboard Tasks
  // -----------------------------------------------------
  task check_tx();
    logic [7:0] exp_d, obs_d;
    logic dummy1, dummy2;
    begin
      forever begin
        @(posedge clk);
        if (exp_tx_data_q.size() > 0 && obs_tx_data_q.size() > 0) begin
          exp_d = exp_tx_data_q.pop_front();
          obs_d = obs_tx_data_q.pop_front();
          dummy1 = exp_tx_par_q.pop_front();
          dummy2 = obs_tx_par_q.pop_front();

          if (obs_d === exp_d) begin
            $display("[SCOREBOARD] TX PASS: expected=0x%02h observed=0x%02h", exp_d, obs_d);
            tx_pass++;
          end else begin
            $display("[SCOREBOARD] TX FAIL: expected=0x%02h observed=0x%02h", exp_d, obs_d);
            tx_fail++;
          end
        end
      end
    end
  endtask

  task check_rx();
    logic [7:0] exp_d, obs_d;
    logic exp_pe, obs_pe;
    logic exp_fe, obs_fe;
    begin
      forever begin
        @(posedge clk);
        if (exp_rx_data_q.size() > 0 && obs_rx_data_q.size() > 0) begin
          exp_d = exp_rx_data_q.pop_front();
          obs_d = obs_rx_data_q.pop_front();
          exp_pe = exp_rx_par_err_q.pop_front();
          obs_pe = obs_rx_par_err_q.pop_front();
          exp_fe = exp_rx_frm_err_q.pop_front();
          obs_fe = obs_rx_frm_err_q.pop_front();

          if (obs_d === exp_d && obs_pe === exp_pe && obs_fe === exp_fe) begin
            $display("[SCOREBOARD] RX PASS: data=0x%02h par_err=%0b frm_err=%0b", obs_d, obs_pe, obs_fe);
            rx_pass++;
          end else begin
            $display("[SCOREBOARD] RX FAIL: exp={0x%02h, %0b, %0b} obs={0x%02h, %0b, %0b}", 
                     exp_d, exp_pe, exp_fe, obs_d, obs_pe, obs_fe);
            rx_fail++;
          end
        end
      end
    end
  endtask

  task report();
    begin
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
    end
  endtask

  // -----------------------------------------------------
  // Test Sequence
  // -----------------------------------------------------
  task send_tx(input logic [7:0] data, input logic par_en);
    begin
      exp_tx_data_q.push_back(data);
      exp_tx_par_q.push_back(par_en);
      drive_tx(data, par_en);
    end
  endtask

  task send_rx(input logic [7:0] data, input logic par_en, input logic inj_par_err, input logic inj_frame_err);
    logic expected_par_err;
    begin
      expected_par_err = (par_en && inj_par_err) ? 1'b1 : 1'b0;
      exp_rx_data_q.push_back(data);
      exp_rx_par_err_q.push_back(expected_par_err);
      exp_rx_frm_err_q.push_back(inj_frame_err);
      
      drive_rx(data, par_en, inj_par_err, inj_frame_err);
      repeat(5) @(posedge clk);
    end
  endtask

  integer tid;
  logic [7:0] rand_data;

  initial begin
    #1000000;
    $display("\n*** SIMULATION TIMEOUT ***\n");
    $finish;
  end

  initial begin
    // $dumpfile("uart_tb.vcd");
    // $dumpvars(0, tb_top);

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
    send_rx(8'hA3, 1'b0, 0, 0);
    send_rx(8'h55, 1'b0, 0, 0);
    $display("T3: Basic RX test complete.\n");

    $display("\n===== T4: MULTIPLE TX TEST =====");
    send_tx(8'h00, 1'b0);
    send_tx(8'hFF, 1'b0);
    send_tx(8'h55, 1'b0);
    send_tx(8'hAA, 1'b0);
    $display("T4: Multiple TX test complete.\n");

    $display("\n===== T5: MULTIPLE RX TEST =====");
    send_rx(8'h00, 1'b0, 0, 0);
    send_rx(8'hFF, 1'b0, 0, 0);
    send_rx(8'h55, 1'b0, 0, 0);
    send_rx(8'hAA, 1'b0, 0, 0);
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
      logic [7:0] lb_data;
      lb_data = 8'hBC;
      exp_rx_data_q.push_back(lb_data);
      exp_rx_par_err_q.push_back(1'b0);
      exp_rx_frm_err_q.push_back(1'b0);

      parity_en <= 1'b0;
      @(posedge clk);

      fork : loopback_fork
        begin // TX side
          exp_tx_data_q.push_back(lb_data);
          exp_tx_par_q.push_back(1'b0);
          drive_tx(lb_data, 1'b0);
        end
        begin // Loopback wire
          forever begin
            @(posedge clk);
            rx_serial <= tx_serial;
          end
        end
      join_any
      disable loopback_fork;
      
      repeat(20) @(posedge clk);
      rx_serial <= 1'b1;
      @(posedge clk);
    end
    $display("T11: Loopback test complete.\n");

    $display("\n===== T12: RANDOM TX TEST =====");
    for (tid = 0; tid < 20; tid = tid + 1) begin
      rand_data = $random;
      send_tx(rand_data, 1'b0);
    end
    $display("T12: Random TX test complete.\n");

    $display("\n===== T13: RANDOM RX TEST =====");
    for (tid = 0; tid < 20; tid = tid + 1) begin
      rand_data = $random;
      send_rx(rand_data, 1'b0, 0, 0);
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

    repeat (100) @(posedge clk);
    report();

    $display("\n*** SIMULATION COMPLETE ***\n");
    $finish;
  end

endmodule
