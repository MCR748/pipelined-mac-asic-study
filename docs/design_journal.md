# Design Journal – Pipelined MAC Accelerator

This document records the chronological design iterations of a fixed-point MAC accelerator developed with ASIC timing closure as the primary objective.

The journal captures:
- design decisions and architectural assumptions,
- timing and physical-design-related failures,
- observations from synthesis, STA, and layout,
- and how the design evolved based on those observations.

Entries are chronological and reflect hypotheses made before observing synthesis or physical results.


## Iteration 0 – Project Definition & Baseline Assumptions

### Goal
Define the scope, architectural intent, and learning objectives of the MAC accelerator prior to RTL implementation.

The objective is to move from theoretical ASIC knowledge (STA, synthesis, and physical effects) to practical ownership of a timing-critical datapath through iterative design and analysis.

---

### Problem Statement
Previous RTL design experience was largely FPGA-centric, where aggressive timing, wire delay, and loop-carried dependencies are often abstracted by vendor tools.

This project is intended to explicitly expose those ASIC-specific constraints using a deliberately timing-stressful datapath: a fixed-point MAC with accumulation feedback.

---

### Target Design
A fixed-point MAC accelerator performing repeated operations of the form:

    acc = acc + (A × B)

Key characteristics:
- Signed fixed-point arithmetic
- Aggressive clock target
- Pipelined datapath
- Initial focus on datapath only (no bus protocol)
- Later integration with APB for control and observation

---

### Initial Design Decisions

#### Datapath Precision
- Operand A: 16-bit signed
- Operand B: 16-bit signed
- Product width: 32-bit signed
- Accumulator width: 40-bit signed

This selection balances implementation complexity with sufficient arithmetic and feedback pressure to expose timing limitations.

---

#### Clocking and Reset
- Single global clock
- Synchronous, active-high reset

This simplifies timing analysis and avoids asynchronous-reset-related complications during STA and CTS.

---

#### Target Frequency
- Target clock frequency: **500 MHz**

The target is intentionally aggressive for Sky130 and is expected to fail initially.Timing failure is treated as an expected outcome used to guide architectural refinement.

---

#### Architectural Strategy
The project is structured in stages:

0. **Stage 0 – Toolchain Bring-Up and Baseline Setup**
   - LibreLane-based ASIC flow setup (Dockerized execution, Sky130 PDK)
   - Minimal test design to validate synthesis, STA, and PnR flow
   - Definition of baseline constraints (clock, reset, I/O assumptions)
   - Establishment of reproducible flow before RTL experimentation
   - Toolchain versions are pinned and reproducible via LibreLane’s Dockerized environment
   - #### Toolchain Reproducibility Note
      - Initial attempts were made to reproduce the LibreLane toolchain using a Nix-based environment. This approach exposed incompatibilities between pinned Yosys versions and plugin stacks, resulting in non-actionable infrastructure failures unrelated to datapath design.
      - To preserve focus on ASIC timing and architectural iteration, the project transitioned to LibreLane’s officially supported Dockerized execution path. This environment provides a coherent, version-locked toolchain validated by upstream and was verified via the official LibreLane smoke test.
      - All subsequent iterations assume the Dockerized LibreLane environment.

1. **Stage 1A – Naïve MAC**
   - Single-cycle accumulation
   - Unpipelined multiplier and adder
   - Expected to violate timing

2. **Stage 1B – Multiplier-Pipelined MAC**
   - Multiplier decomposed into pipeline sub-stages
   - Accumulator adder remains unpipelined
   - Accumulation remains cycle-accurate
   - Intended to reduce combinational depth while preserving baseline semantics

3. **Stage 1C – Adder-Pipelined MAC**
   - Accumulator adder decomposed into pipeline sub-stages
   - Latency-correct (not cycle-accurate) accumulation
   - Explicit breaking of loop-carried critical paths

4. **Stage 2 – Control Integration**
   - APB-based register interface
   - Analysis of control-to-datapath fanout and timing impact


---

### Hypotheses (Pre-RTL)
- The accumulator feedback path (acc_reg → adder → acc_reg) will dominate the critical path.
- Pipelining the multiplier alone will be insufficient to meet the target  frequency.
- Pipelining the accumulator without redefining semantics will introduce  functional mismatches.
- Post-CTS timing will degrade further due to wire delay and clock effects.

---

### Artifacts to be Collected
Each stage will record:
- Worst negative slack (WNS) and critical path description
- Register-to-register path details from STA
- Area and cell composition changes across iterations
- Pre-CTS vs post-CTS timing differences where applicable

These artifacts are used to justify architectural changes between stages.

---

### Success Criteria
This iteration is considered successful if:
- Timing violations are observed and explained
- STA results can be correlated to RTL structure
- Pipeline decisions are driven by timing evidence
- Accumulation correctness is preserved under latency-aware semantics

---

### Next Step
Complete **Stage 0 – Toolchain Bring-Up and Baseline Setup** by validating the LibreLane + Sky130 flow using a trivial register-based design, ensuring that synthesis, STA, CTS, and routing reports are interpretable before introducing datapath complexity.

---

## Iteration 1 – Stage 0.2: Baseline RTL Discipline and Reset Semantics

During Stage 0.2, the baseline RTL was revised to remove FPGA-centric assumptions that interfered with establishing a clean ASIC timing reference.

---

### Reset Semantics

   - The initial RTL used an asynchronous reset.
   - This was identified as problematic for baseline timing analysis due to:
     - Introduction of reset recovery and removal timing checks.
     - Reset deassertion behaving as an independent timing event.
     - Reset skew not being managed by clock tree synthesis.
     - Ambiguity in STA results when isolating datapath-related timing effects.

   **Decision**
   - Replace asynchronous reset with a synchronous, active-high reset.

   **Rationale**
   - Synchronous reset:
     - Is sampled only on the clock edge.
     - Eliminates recovery/removal timing constraints.
     - Avoids introducing an additional global control tree.
     - Keeps reset behavior within the normal clocked timing domain.

---

### Baseline Timing Discipline

   - Stage 0 timing measurements are intended to reflect:
     - Register-to-register paths.
     - Clock behavior and uncertainty.
     - Toolchain interpretation of basic synchronous logic.

   - To preserve this intent:
     - Additional global control paths (e.g., asynchronous reset trees) are avoided.
     - Special-case timing constraints are deferred to later stages.

---

### Working Guidelines Established

   - Synchronous resets are preferred for datapath-oriented ASIC designs.
     - Reset behavior should not introduce independent timing domains during early analysis.
   - Baseline timing measurements should minimize non-datapath effects.
     - Timing results should be attributable to RTL structure, not control infrastructure.
   - FPGA reset conventions are not assumed to be valid for ASIC flows.
     - Reset semantics must be evaluated explicitly in the context of STA and CTS.

---

### Status

   - The baseline RTL is now:
     - Fully synchronous.
     - Deterministic.
     - Suitable for unambiguous interpretation of synthesis, STA, and physical design results.




