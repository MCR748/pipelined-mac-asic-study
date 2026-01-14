# Pipelined MAC Accelerator – ASIC Timing & Datapath Study

This repository documents an end-to-end ASIC-focused study of a fixed-point
Multiply–Accumulate (MAC) accelerator, with emphasis on:

- Datapath timing closure
- Pipeline vs latency tradeoffs
- Loop-carried dependency challenges in accumulation
- RTL-to-synthesis-to-physical interactions

The design targets an aggressive 500 MHz clock frequency in the Sky130
technology to intentionally expose timing, fanout, and wire-dominated effects
that are typically hidden in FPGA implementations.

This project is structured as a chronological engineering log rather than a
tutorial. All major architectural decisions, timing failures, and fixes are
documented as they occurred.

**Primary artifact:** `docs/design_journal.md`
