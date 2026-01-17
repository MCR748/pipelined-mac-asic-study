# Pipelined MAC Accelerator – ASIC Timing & Datapath Study

This repository documents an end-to-end ASIC-focused study of a fixed-point Multiply–Accumulate (MAC) accelerator, with emphasis on:
    - Datapath timing closure
    - Pipeline vs latency tradeoffs
    - Loop-carried dependency challenges in accumulation
    - RTL-to-synthesis-to-physical interactions

The design targets an aggressive 500 MHz clock frequency in the Sky130 technology to intentionally expose timing, fanout, and wire-dominated effects that are typically hidden in FPGA implementations.

This project is structured as a chronological engineering log rather than a tutorial. All major architectural decisions, timing failures, and fixes are documented as they occurred.

## Architectural Learnings

This project derives a set of timing-driven architectural rules for high-frequency ASIC datapaths.

See:
- `docs/architectural_learnings.md` — architectural rules derived from timing analysis
- `docs/design_journal.md` — chronological record of experiments, observations, and outcomes

## Project Status

This repository captures a **completed architectural exploration phase** of a high-frequency ASIC MAC datapath.

The goal of this phase was not unconditional timing closure, but to:
- Expose structural timing limits
- Derive non-negotiable architectural rules
- Separate conceptual correctness from physical feasibility

As documented in the design journal, this phase concludes with known limitations (e.g., unsigned multiplication and worst-case timing violations) that are explicitly acknowledged and used to define the scope of subsequent work.

The repository should therefore be read as an **engineering investigation and architecture study**, not as a production-ready MAC implementation.
