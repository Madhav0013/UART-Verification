// File: tb/uart_env.sv
// Description: Verification environment — connects all components

class uart_env;

  uart_driver     driver;
  uart_monitor    monitor;
  uart_scoreboard scoreboard;
  uart_coverage   coverage;

  virtual uart_if.DRV drv_vif;
  virtual uart_if.MON mon_vif;

  function new(virtual uart_if.DRV drv_vif, virtual uart_if.MON mon_vif, int clks_per_bit = 16);
    this.drv_vif = drv_vif;
    this.mon_vif = mon_vif;

    driver     = new(drv_vif, clks_per_bit);
    monitor    = new(mon_vif, clks_per_bit);
    scoreboard = new();
    coverage   = new();

    // Connect monitor mailboxes to scoreboard
    scoreboard.connect(monitor.tx_mbx, monitor.rx_mbx);
  endfunction

  task start();
    monitor.run();
    scoreboard.run();
  endtask

  function void report();
    scoreboard.report();
    coverage.report();
  endfunction

endclass
