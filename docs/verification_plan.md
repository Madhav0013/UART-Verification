# UART Verification Plan

## 1. Features to Verify

| ID   | Feature                  | Priority |
|------|--------------------------|----------|
| F1   | Reset behavior           | High     |
| F2   | TX single byte           | High     |
| F3   | RX single byte           | High     |
| F4   | TX multiple bytes        | High     |
| F5   | RX multiple bytes        | High     |
| F6   | Parity generation (TX)   | High     |
| F7   | Parity checking (RX)     | High     |
| F8   | Parity error detection   | High     |
| F9   | Framing error detection  | High     |
| F10  | Back-to-back transfers   | Medium   |
| F11  | Loopback (TX→RX)         | Medium   |
| F12  | Idle line behavior       | Medium   |
| F13  | Random data patterns     | Medium   |

## 2. Directed Test Cases

| Test | Name                    | Description                                          | Feature |
|------|-------------------------|------------------------------------------------------|---------|
| T1   | reset_test              | Assert reset, check all outputs at default           | F1      |
| T2   | tx_basic                | Transmit 0x55, verify serial frame                   | F2      |
| T3   | rx_basic                | Drive valid frame for 0xA3, check rx_data            | F3      |
| T4   | tx_multiple             | Transmit 0x00, 0xFF, 0x55, 0xAA sequentially         | F4      |
| T5   | rx_multiple             | Drive 4 valid frames, check each rx_data             | F5      |
| T6   | tx_parity               | TX with parity_en=1, verify parity bit               | F6      |
| T7   | rx_parity_good          | Drive frame with correct parity, verify no error     | F7      |
| T8   | rx_parity_error         | Drive frame with wrong parity, check parity_error=1  | F8      |
| T9   | rx_framing_error        | Drive frame with stop bit=0, check framing_error=1   | F9      |
| T10  | back_to_back            | TX 3 frames without gap, verify all                  | F10     |
| T11  | loopback                | Connect tx_serial→rx_serial, verify echo             | F11     |
| T12  | random_tx               | TX 20 random bytes, verify all frames                | F13     |
| T13  | random_rx               | Drive 20 random frames, verify all rx_data           | F13     |
| T14  | parity_err_then_valid   | Bad parity frame → good frame, verify recovery       | F8      |
| T15  | framing_err_then_valid  | Bad stop bit frame → good frame, verify recovery     | F9      |

## 3. Assertions

| ID  | Property                                                    |
|-----|-------------------------------------------------------------|
| A1  | tx_serial == 1 when TX FSM is in IDLE and not in reset     |
| A2  | tx_serial == 0 during START bit state                       |
| A3  | tx_serial == 1 during STOP bit state                        |
| A4  | tx_done pulses for exactly 1 cycle                          |
| A5  | rx_done pulses for exactly 1 cycle                          |
| A6  | After reset, tx_serial == 1 within 1 cycle                  |
| A7  | parity_error only asserts when parity_en == 1               |
| A8  | tx_busy == 1 during entire frame transmission               |

## 4. Functional Coverage

| CG  | Coverpoint / Cross              | Bins                              |
|-----|---------------------------------|-----------------------------------|
| C1  | tx_data value                   | 0x00, 0xFF, 0x55, 0xAA, others   |
| C2  | rx_data value                   | 0x00, 0xFF, 0x55, 0xAA, others   |
| C3  | parity_en                       | 0, 1                              |
| C4  | parity_error occurred           | 0, 1                              |
| C5  | framing_error occurred          | 0, 1                              |
| C6  | back_to_back TX                 | hit / not hit                     |
| C7  | tx_data × parity_en             | cross coverage                    |
| C8  | error followed by valid frame   | hit / not hit                     |
