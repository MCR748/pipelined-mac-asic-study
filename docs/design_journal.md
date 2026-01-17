# Design Journal – Pipelined MAC Accelerator

- This document records the chronological design iterations of a fixed-point MAC accelerator, with **ASIC timing closure** as the primary objective.

- The journal captures:
    - Architectural decisions and underlying assumptions  
    - Timing- and physical-design-related failures  
    - Observations from synthesis, STA, CTS, and routing  
    - Architectural evolution driven by measured results  

- Entries are added in chronological order and the goals hypothesis can change over time as seen fit.

## Iteration 0 – Project Definition and Baseline Assumptions

### Objective
- Define scope, architectural intent, and learning objectives before RTL development.
- Transition from theoretical ASIC concepts (STA, synthesis, physical effects) to practical ownership of a timing-critical datapath through iterative design and analysis.

### Problem Statement
- Prior RTL experience was predominantly FPGA-oriented, where aggressive timing, wire delay, and loop-carried dependencies are largely abstracted by vendor tooling.
- This project explicitly targets ASIC-specific constraints using a deliberately timing-stressful datapath: a fixed-point MAC with accumulation feedback.

### Target Computation
- A fixed-point MAC performing:
    ```
    acc = acc + (A × B)
    ```
- Key characteristics:
    - Signed fixed-point arithmetic  
    - Aggressive clock target  
    - Deeply pipelined datapath  
    - Initial focus on datapath only (no bus interface)  
    - Integration with APB or similar protocol for control and observability  

### Initial Design Decisions

- #### Datapath Precision
    - Operand A: 16-bit signed  
    - Operand B: 16-bit signed  
    - Product width: 32-bit signed  
    - Accumulator width: 40-bit signed  

    This configuration balances implementation complexity while applying sufficient arithmetic and feedback pressure to expose timing limits.

- #### Clocking and Reset
    - Single global clock  
    - Synchronous, active-high reset  

    Chosen to simplify STA and avoid asynchronous reset recovery/removal complications during CTS.

#### Target Frequency
- 500 MHz

This target is intentionally aggressive for Sky130. Initial timing failure is expected and treated as an input to architectural refinement.

### Architectural Staging Plan

- #### Stage 0 – Toolchain Bring-Up and Baseline Setup
    - LibreLane-based ASIC flow (Dockerized, Sky130 PDK)  
    - Minimal test design to validate synthesis, STA, CTS, and PnR  
    - Definition of baseline constraints (clock, reset, I/O assumptions)  
    - Establishment of a reproducible flow prior to datapath experimentation  
    - Tool versions pinned via LibreLane’s Docker environment  

- #### Stage 1A – Unsigned Multiplier Timing Closure
    - Fully registered datapath skeleton  
    - Implement an appropriate unsigned multiplier with  
    - No accumulation feedback  

- #### Stage 1B – Unsigned Accumulator Timing Closure
    - Accumulator adder and feedback introduced    
    - Unsigned multiplier retained unchanged  

- #### Stage 1C – Signed Arithmetic Integration
    - Implement signed multiplier  
    - Restructure and pipeline Stage-0 logic if required
    - Try achieve better timing closure 

- #### Stage 2 – Control Integration
    - Implement APB (or similar protocol) based register interface  
    - Analysis of control-to-datapath fanout and timing impact  

### Pre-RTL Hypotheses
- Accumulator feedback (acc_reg → adder → acc_reg) will dominate the critical path.  
- Pipelining the multiplier alone will be insufficient to meet 500 MHz.  
- Pipelining the accumulator without semantic redefinition will break correctness.  

### Artifacts Collected per Stage
- Worst negative slack (WNS) and critical path descriptions  
- Register-to-register STA path details  
- Area and cell composition changes  
- Pre-CTS versus post-CTS timing deltas  

These artifacts justify architectural decisions between iterations.

### Success Criteria
- Timing violations are observed and explained  
- STA results correlate directly with RTL structure  
- Pipeline decisions are driven by measured timing evidence  

### Stage 0 Execution Observations


- #### Toolchain Reproducibility
    - Initial attempts to reproduce the LibreLane flow using a Nix-based environment exposed incompatibilities between pinned Yosys versions and plugin stacks.
    - Hence the project transitioned to LibreLane’s officially supported Dockerized environment.
    - The Docker-based flow was validated using the upstream LibreLane smoke test.
    - All subsequent iterations assume this Dockerized execution environment.

- ### Functional Sanity Checking (Pre-ASIC Flow)
    - Prior to running synthesis and physical-design stages, basic functional sanity was established using cycle-accurate simulation.
    - Simulation was used to:
        - Validate reset behavior and pipeline latency  
        - Confirm register-to-register data propagation  
        - Detect semantic mismatches between intended behavior and RTL implementation  

## Iteration 1 – Stage 0.2: Baseline RTL Discipline and Reset Semantics

- ### Reset Semantics
    - Initial RTL used an asynchronous reset.
    - Identified issues:
      - Recovery and removal timing checks  
      - Reset deassertion as an independent timing event  
      - Reset skew unmanaged by CTS  
      - Ambiguity in the cause of timing error, due to data path or reset control 

    - **Decision** : Replace asynchronous reset with a synchronous, active-high reset.

    - #### Rationale
        - Sampled only on clock edges
        - Eliminates recovery/removal constraints  
        - Avoids an independent global control tree  
        - Keeps reset behavior within the clocked timing domain  


- ### Baseline Timing Discipline
    - Stage 0 timing intended to reflect:
        - Register-to-register paths  
        - Clock behavior and uncertainty  
        - Tool interpretation of synchronous logic  

    - To preserve this:
        - Global control paths avoided (Async reset, clock gating)  
        - Special-case constraints deferred (reset set to false path) 

    - #### Tool Noise vs Architectural Signal
        - Early STA violations originated from:
          - Reset fanout  
          - Unconstrained I/O ports  
          - Default external timing assumptions  

        - **Resolution** : Explicit SDC constraints introduced:
          - Reset paths excluded from datapath timing  
          - I/O timing assumptions defined  
          - Default constraints replaced with explicit definitions  

        - **Established Principle** : Architectural decisions are driven only by internal register-to-register datapath violations under well-defined constraints.

- ### Working Guidelines
    - Prefer synchronous resets in datapath-focused ASIC designs  
    - Minimize non-datapath effects in baseline timing  
    - Do not assume FPGA reset conventions apply to ASIC flows  


- ### Status
    - Baseline RTL is fully synchronous, deterministic, and suitable for unambiguous interpretation of synthesis, STA, and physical-design results.

## Iteration 2 – Multiplier Reduction vs Final Addition: Timing Reality

- ### Wallace / CSA Tree Behavior
    - Multiplier implemented as:
      - Partial-product generation  
      - Multi-level CSA reduction  
      - Final CPA  

    - Observations:
        - CSA stages scale well with pipelining  
        - Additional CSA levels do not significantly degrade timing when registered  
        - Final CPA consistently dominates the critical path  

- ### Uniform Pipelining Does Not Imply Uniform Timing
    - All stages were registered, yet violations persisted.
    - Root cause:
      - Carry propagation in the CPA creates a serial dependency  
      - This logic depth dominates cycle time regardless of register placement  


- ### STA Evidence
    - Post-CTS critical path:
        ```
        r_stg3/Q → CPA → r_o_val/D
        ```
    - WNS improved from approximately –0.71 ns to –0.50 ns after adjustments.
    - Critical paths consistently traversed carry-chain bits (e.g., `adder_b[8]`).

    - **Additional observation**: Adding a register immediately before the CPA improved slack due to reduced fanout and electrical load, not reduced logic depth.

- ### Architectural Conclusion
    - CSA trees are parallel reduction structures and scale with pipelining.
    - CPAs are serial propagation structures and fundamentally frequency-limiting.
    - Tool optimization alone cannot resolve CPA-dominated paths.

- ### Signed Multiplication Insight
    - Signed multiplication introduces:
      - Sign extension  
      - MSB partial-product negation  
      - Correction terms  

    - These increase logic depth and fanout in early stages.
        - Modifying an unsigned mutlplier to signed is difficult without major architectural revision.
        - Hence signed arithmetic must be treated as a first-class architectural decision.

## Iteration 2 (Continued) – Full-Pipeline Necessity

- ### Brent–Kung Adder: Mid-Tree Pipelining Failure
    - Selective mid-tree pipelining was insufficient.
    - STA violations persisted inside prefix logic under worst-case corners.
    - Partial pipelining of propagation structures is ineffective at 500 MHz in Sky130.


- ### Fully Pipelined Prefix Adder
    - Implementation
        - One prefix-combine level per stage  
        - Registers between every level  
        - Final carry and sum isolated  

    - Result
        - Increased latency but predictable timing
        - Stable worst-case timing  
        - Bounded per-stage logic depth  

- ### Fully Pipelined Wallace Tree
    - Implementation
        - One CSA level per cycle  
        - Registers between every CSA stage  
        - Carry shifting externalized  

    - Outcome
        - Eliminated multi-level CSA paths per cycle  
        - Removed unbounded routing delay  
        - Matches industrial high-frequency multiplier practice  

- ### Consolidated Architectural Principles
    - Propagation and reduction structures differ fundamentally  
    - Partial pipelining is insufficient for CPAs  
    - “Fully registered” does not imply timing-safe  
    - Worst-case PVT corners dictate architecture  
    - FPGA intuition is unreliable for ASIC timing  
    - Deep, explicit pipelining is mandatory at aggressive frequencies  

## Iteration 3 – Stage 1B: Architectural Resolution of Accumulation Feedback

- ### CPA-Based Accumulator Failure
    - Pipelined CPA breaks the accumulation recurrence.
    - Accumulators cannot be multi-cycle without additional mechanisms.

- ### CSA-Based Accumulator
    - Maintain `acc_sum` and `acc_carry`.
    - Perform carry-save addition each cycle without propagation.
    - Results :
        - Correct semantics preserved  
        - Feedback timing reduced to CSA logic  

- ### Canonicalization Outside the Loop
    - Brent–Kung CPA used only for readout.
    - Fully pipelined and excluded from feedback semantics.

- ### Control vs Datapath Separation
    - Control gating introduced hidden critical paths.
    - Resolution:
      - Remove gating  
      - Inject zeros on invalid cycles for accumulator  
      - Update arithmetic state unconditionally  

- ### Full-Flow Outcome
    - Complete LibreLane flow executed successfully.
    - Timing and signal-integrity warnings remained at worst-case corners.

- ### Timing Summary
    - **Target:** 500 MHz (2.0 ns)
    - Typical corner: Pass  
    - SS @ 100 °C: Fail  
    - Worst-case SS @ 100 °C, 1.60 V: Fail  
    - Violations:
        - Setup and slew violations post-CTS  
        - Resizer unable to fully repair paths  

- ### Interpretation
    - Architectural issues have been resolved.
    - Remaining failures are physical:
        - Wire delay  
        - Fanout  
        - Slew  
        - Clock uncertainty  

    This marks the transition from architectural limitation to technology limit.

## Phase Closure – End of Unsigned MAC Exploration

- ### Known Limitations
    - Multiplier is unsigned  
    - Wallace tree and CSA accumulator fail worst-case timing due to physical limits  

- ### Interpretation
    - Architecture is structurally correct.
    - 500 MHz does not meet reliable worst-case operation in Sky130.

- ### Rationale for Phase Termination
    - Further iteration yields diminishing architectural insight.
    - Structural and physical limits are now clearly separated.

- ### Next Phase Objectives
    - Introduce signed multiplication as a first-class architecture  
    - Re-evaluate accumulator timing under signed operation  
    - Explicitly define success as closure, explainability, or infeasibility  

- ### Phase Transition
    - This concludes the **Unsigned MAC Architectural Exploration Phase**. Subsequent work proceeds as mentioned under *Next Phase Objectives*.

## Iteration 3.1 – CSA Input Registration to Isolate Control Logic

- ### On Accumulator circuit CSA

    - #### Change
        - The CSA accumulator exhibited timing degradation due to control-dependent logic in its input cone, specifically the `mul_valid`-gated mux feeding the CSA operand.
        - To eliminate this, the muxed product value was registered, capturing the `product_or_zero` result in a dedicated pipeline register prior to the CSA.
        - This ensured that all CSA inputs (`acc_sum`, `acc_carry`, `product`) are register-sourced, removing multiplier control logic from the accumulator feedback path.

    - #### Timing Impact
        - This modification eliminated several previously observed violations involving control-to-accumulator paths, including:
            - `u_mac_mul.o_mul_valid → r_acc_sum[*]`
            - `u_mac_mul.o_mul_valid → r_acc_carry[*]`

        - Post-route STA confirmed that these paths no longer contribute to the critical timing cone, indicating improved isolation of the accumulator loop.

    - #### Residual Violation
        - A marginal setup violation remains on the accumulator feedback path itself:
            ```
            r_acc_sum[i]/Q → CSA logic → r_acc_sum[i]/D
            ```
        - This is a single-cycle register-to-itself path within the CSA-based accumulation loop, with worst negative slack on the order of a few picoseconds.
        - This hits the technology-imposed frequency limit as only CSA feedback path remains, unless an architectural revision is considered.
        - This residual violation reflects a technology-limited CSA feedback path, where the worst-case bit is determined by physical placement and routing rather than arithmetic significance.

- ### On Wallace tree CSA
    - #### Observation
        - Gate-level netlist inspection was performed on the reported violating paths.
        - The inspected paths confirm that each CSA level is terminated by a register.
        - Specifically, CSA_L3 combinational logic feeds a flip-flop, and CSA_L4 logic begins from that register output:
            ```
            r_stg3[x][bit]/Q → CSA_L4 logic → r_stg4[y][bit]/D
            ```
        - No unintended combinational chaining exists between CSA stages.
        - RTL intent (“one CSA level per cycle”) is preserved through synthesis and PnR.

    - #### Implication
        - The observed timing violations are not caused by missing or absorbed registers.
        - The architectural structure of the CSA pipeline is correct and unchanged.
        - Despite correct registration, setup violations persist, indicating a technology-limited single-cycle CSA datapath at the target frequency.

    - #### Conclusion
        - The remaining failures are:
            - Datapath-only
            - Single-cycle
            - Bit-selective
            - Independent of control logic
        - Further PnR effort is unlikely to resolve these violations.
        - Timing closure at 500 MHz would require architectural modification or a reduced clock target.



