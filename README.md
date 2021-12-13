# CPU_Shieru

> SJTU ACM Class Architecture 2021 Assignment ( MS108 Course Project )

A toy but high performance RISC-V CPU.

![](https://img.shields.io/badge/Language-Verilog-blue) ![](https://img.shields.io/badge/Run%20on-XC7A35T--ICPG236C%20FPGA%20Board-ff69b4) ![](https://img.shields.io/badge/all%20testcases-passed-brightgreen)

## Intro

- Maybe one of the Top Performance CPU in ACM Class 2020.
- Able to operate correctly under 120 MHz frequency ( passed all testcases ).
- Not much resources consumed ( 59% LUT ).

## Architecture
 - [x] Out-of-order execution by Tomasulo Algorithm.
 - [x] 16 entries RS, 16 entries LSB and 16 entries ROB.
 - [x] Branch Prediction with 512 entries Branch History Buffer.
 - [x] 512 entries Direct-Mapped I-Cache.
 - [ ] Double Issue.

## Performance


| Testcase | Time (100Mhz) | Time (120 Mhz) |
|:--:|:--:|:--:|
| heart | 310.34s | 265.08s |
| qsort | 6.48s | 5.39s |
| queens | 3.15s | 2.60s |
| hanoi | 3.47s | 2.90s |
| bulgarian | 1.65s | 1.30s |
| pi | 1.32s | 1.15s |

**Higher frequency waiting for testing**.

