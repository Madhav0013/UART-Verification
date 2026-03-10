# UART Design Specification

## 1. Overview
This document specifies the behavior of a UART transmitter (TX) and receiver (RX) module.

## 2. Parameters
| Parameter     | Default | Description                        |
|---------------|---------|------------------------------------|
| CLKS_PER_BIT  | 16      | System clock cycles per UART bit   |
| PARITY_EN     | 0       | 0 = no parity, 1 = even parity    |

## 3. Interface Signals

### Inputs
| Signal        | Width | Description                                      |
|---------------|-------|--------------------------------------------------|
| clk           | 1     | System clock                                     |
| rst_n         | 1     | Active-low synchronous reset                     |
| tx_start      | 1     | Pulse high for 1 cycle to begin transmission     |
| tx_data       | 8     | Byte to transmit (latched on tx_start)           |
| rx_serial     | 1     | Serial input to receiver                         |
| parity_en     | 1     | Runtime parity enable (1=even parity, 0=none)    |

### Outputs
| Signal        | Width | Description                                      |
|---------------|-------|--------------------------------------------------|
| tx_serial     | 1     | Serial output from transmitter                   |
| tx_busy       | 1     | High while transmitter is sending a frame        |
| tx_done       | 1     | Pulses high for 1 cycle when frame is complete   |
| rx_data       | 8     | Received byte (valid when rx_done=1)             |
| rx_done       | 1     | Pulses high for 1 cycle when reception complete  |
| parity_error  | 1     | High for 1 cycle if parity mismatch detected     |
| framing_error | 1     | High for 1 cycle if stop bit is not 1            |

## 4. Reset Behavior
After rst_n is asserted (low) and then deasserted (high):
- tx_serial = 1 (idle)
- tx_busy = 0
- tx_done = 0
- rx_done = 0
- parity_error = 0
- framing_error = 0
- TX and RX state machines return to IDLE

## 5. TX Behavior
1. In IDLE, tx_serial = 1, tx_busy = 0.
2. When tx_start pulses high, latch tx_data, assert tx_busy.
3. Send START bit (0) for CLKS_PER_BIT cycles.
4. Send data[0] through data[7] (LSB first), each for CLKS_PER_BIT cycles.
5. If parity_en=1, send even parity bit for CLKS_PER_BIT cycles.
6. Send STOP bit (1) for CLKS_PER_BIT cycles.
7. Assert tx_done for 1 cycle, deassert tx_busy, return to IDLE.

## 6. RX Behavior
1. In IDLE, wait for rx_serial falling edge (start bit detection).
2. Wait CLKS_PER_BIT/2 cycles to reach mid-bit of start bit. Confirm it is 0.
3. Sample data[0] through data[7] at mid-bit (every CLKS_PER_BIT cycles). LSB first.
4. If parity_en=1, sample parity bit at mid-bit. Check even parity. If mismatch, assert parity_error.
5. Sample stop bit at mid-bit. If not 1, assert framing_error.
6. Assert rx_done for 1 cycle. Output rx_data. Return to IDLE.

## 7. Frame Diagram
```
Idle  | START | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | [PAR] | STOP | Idle
  1   |   0   | b0 | b1 | b2 | b3 | b4 | b5 | b6 | b7 | [p]   |  1   |  1
```
Each bit occupies CLKS_PER_BIT clock cycles.
