# Complete UART Verification Project

A fully self-checking SystemVerilog verification environment for a UART Transmitter and Receiver. This project demonstrates industry-standard verification concepts, including a robust protocol design, modular testbenches, error injection mechanisms, automated scoreboarding, and SystemVerilog Assertions (SVA).

**Note:** The testbench and assertions have been specifically engineered to be 100% compatible with the open-source **Icarus Verilog** (`iverilog`) simulator.

## Project Structure
```text
uart_verification/
├── rtl/
│   └── uart.sv               # Main Synthesizable UART Design
├── docs/
│   ├── spec.md               # Device Specification
│   └── verification_plan.md  # Verification Test Plan
├── tb/
│   ├── tb_top.sv             # Top-Level Testbench Module
│   ├── uart_if.sv            # Protocol Interface
│   └── uart_assertions.sv    # SVAs and Protocol Checkers
├── sim/
│   ├── filelist.f            # Compilation targets
│   └── Makefile              # Commands for automation
└── results/
    └── summary.md            # Simulation Results Report
```

## Features Verified
* Base TX/RX data transmission and framing.
* Configurable clock division via `CLKS_PER_BIT`.
* Expected responses with configurable even parity generation and checking.
* Correct identification and assertion of `parity_error` and `framing_error` flags during RX decoding.
* Assertions actively verifying protocol timings and bounds during runtime.

## Running the Simulation

**Prerequisites:** Ensure `iverilog` and `vvp` are installed in your PATH.

1. Navigate to the `sim` directory:
   ```bash
   cd sim
   ```

2. Compile and run:
   ```bash
   iverilog -g2012 -I../tb -o uart_tb.vvp -f filelist.f
   vvp uart_tb.vvp
   ```

Upon completion, a summary report of all tests will be printed directly to standard output, verifying zero failures.
