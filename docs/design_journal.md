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

### Problem Statement
Previous RTL design experience was largely FPGA-centric, where aggressive timing, wire delay, and loop-carried dependencies are often abstracted by vendor tools.

This project is intended to explicitly expose those ASIC-specific constraints using a deliberately timing-stressful datapath: a fixed-point MAC with accumulation feedback.

### Target Design
A fixed-point MAC accelerator performing repeated operations of the form:

    acc = acc + (A × B)

Key characteristics:
- Signed fixed-point arithmetic
- Aggressive clock target
- Pipelined datapath
- Initial focus on datapath only (no bus protocol)
- Later integration with APB for control and observation

### Initial Design Decisions

#### Datapath Precision
- Operand A: 16-bit signed
- Operand B: 16-bit signed
- Product width: 32-bit signed
- Accumulator width: 40-bit signed

This selection balances implementation complexity with sufficient arithmetic and feedback pressure to expose timing limitations.

#### Clocking and Reset
- Single global clock
- Synchronous, active-high reset

This simplifies timing analysis and avoids asynchronous-reset-related complications during STA and CTS.

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

   #### Toolchain Reproducibility Note
      - Initial attempts were made to reproduce the LibreLane toolchain using a Nix-based environment. This approach exposed incompatibilities between pinned Yosys versions and plugin stacks, resulting in non-actionable infrastructure failures unrelated to datapath design.
      - To preserve focus on ASIC timing and architectural iteration, the project transitioned to LibreLane’s officially supported Dockerized execution path. This environment provides a coherent, version-locked toolchain validated by upstream and was verified via the official LibreLane smoke test.
      - All subsequent iterations assume the Dockerized LibreLane environment.
   
   #### Functional Sanity Checking (Pre-ASIC Flow)
      - Prior to running synthesis and physical-design stages, basic functional sanity of the datapath was established using cycle-accurate simulation.
      - Simulation was used strictly to:
         - Validate reset behavior and pipeline latency.
         - Verify register-to-register data propagation.
         - Detect semantic mismatches between intended datapath behavior and RTL implementation.
      - Simulation results were not used to justify timing decisions, only to confirm correctness before entering the ASIC flow.

1. **Stage 1A – Unsigned Multiplier Timing Closure**
   - Datapath skeleton with fully registered pipeline stages
   - Implementation of an **unsigned** multiplier using partial-product generation, CSA reduction, and a final carry-propagate adder (CPA)
   - Focus on isolating and closing timing on the multiplier datapath
   - No accumulation feedback
   - Signed arithmetic explicitly deferred
   - Objective is to characterize CSA vs CPA timing behavior under aggressive clock targets

2. **Stage 1B – Unsigned Accumulator Timing Closure**
   - Unsigned multiplier from Stage 1A retained without modification
   - Accumulator adder and feedback path introduced
   - Loop-carried dependency analyzed and optimized
   - Datapath now functionally represents an **unsigned MAC**
   - Objective is to close timing on the accumulator feedback path independently of signed arithmetic complexity

3. **Stage 1C – Signed Arithmetic Integration**
   - Conversion of the unsigned multiplier from Stage 1B into a **signed** multiplier
   - Introduction of:
     - Sign extension
     - MSB partial-product negation
     - Correction terms (e.g., Baugh–Wooley style)
   - Restructuring and pipelining of Stage-0 logic as required
   - Latency and valid propagation re-aligned
   - Objective is to quantify the timing and structural cost of signed arithmetic on a stabilized datapath

4. **Stage 2 – Control Integration**
   - APB-based register interface
   - Analysis of control-to-datapath fanout and timing impact


### Hypotheses (Pre-RTL)
- The accumulator feedback path (acc_reg → adder → acc_reg) will dominate the critical path.
- Pipelining the multiplier alone will be insufficient to meet the 500 MHz target due to the accumulator feedback path remaining on the critical loop.
- Pipelining the accumulator without redefining semantics will introduce  functional mismatches.
- Post-CTS timing will degrade further due to wire delay and clock effects.

### Artifacts to be Collected
Each stage will record:
- Worst negative slack (WNS) and critical path description
- Register-to-register path details from STA
- Area and cell composition changes across iterations
- Pre-CTS vs post-CTS timing differences where applicable

These artifacts are used to justify architectural changes between stages.

### Success Criteria
This iteration is considered successful if:
- Timing violations are observed and explained
- STA results can be correlated to RTL structure
- Pipeline decisions are driven by timing evidence
- Accumulation correctness is preserved under latency-aware semantics

### Next Step
Complete **Stage 0 – Toolchain Bring-Up and Baseline Setup** by validating the LibreLane + Sky130 flow using a trivial register-based design, ensuring that synthesis, STA, CTS, and routing reports are interpretable before introducing datapath complexity.

---

## Iteration 1 – Stage 0.2: Baseline RTL Discipline and Reset Semantics

During Stage 0.2, the baseline RTL was revised to remove FPGA-centric assumptions that interfered with establishing a clean ASIC timing reference.

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

### Baseline Timing Discipline

   - Stage 0 timing measurements are intended to reflect:
     - Register-to-register paths.
     - Clock behavior and uncertainty.
     - Toolchain interpretation of basic synchronous logic.
   - To preserve this intent:
     - Additional global control paths (e.g., asynchronous reset trees) are avoided.
     - Special-case timing constraints are deferred to later stages.
   - #### Tool Noise vs Architectural Signal:
      - Early static timing analysis produced violations unrelated to the intended datapath, primarily originating from:
         - Synchronous reset fanout paths.
         - Unconstrained input and output ports.
         - Default tool assumptions about external timing environments.
      - These violations were initially indistinguishable from genuine datapath timing failures, obscuring the relationship between RTL structure and reported slack.
      
      - **Resolution and Learning**
         - Rather than ignoring these reports, explicit timing constraints were introduced to formally separate architectural signal from tool noise:
            - Reset paths were constrained such that reset distribution did not participate in datapath timing analysis.
            - Input and output ports were assigned appropriate timing assumptions to prevent artificial register-to-I/O critical paths.
            - Default fallback constraints were replaced with explicit SDC definitions to align STA with the intended synchronous operating model.
         - This process established a critical working principle for subsequent iterations:
         - Architectural decisions are driven only by timing violations that originate from internal register-to-register datapath paths under well-defined constraints.

### Working Guidelines Established

   - Synchronous resets are preferred for datapath-oriented ASIC designs.
     - Reset behavior should not introduce independent timing domains during early analysis.
   - Baseline timing measurements should minimize non-datapath effects.
     - Timing results should be attributable to RTL structure, not control infrastructure.
   - FPGA reset conventions are not assumed to be valid for ASIC flows.
     - Reset semantics must be evaluated explicitly in the context of STA and CTS.

### Status

   - The baseline RTL is now:
     - Fully synchronous.
     - Deterministic.
     - Suitable for unambiguous interpretation of synthesis, STA, and physical design results.

## Iteration 2 – Multiplier Reduction vs Final Addition: Timing Reality Check

This iteration documents architectural insights that emerged only after full synthesis, CTS, and post-route STA. These observations refine earlier assumptions and establish a clear boundary between scalable arithmetic structures and fundamental timing limits.


### A. Wallace / CSA Tree Behavior in Practice

The multiplier was implemented using a classical three-phase structure:

- Partial product generation
- Multi-level carry-save adder (CSA) reduction (Wallace-style)
- Final carry-propagate adder (CPA)

Observations:
- CSA reduction stages scaled well with pipelining.
- Additional CSA levels did not significantly degrade timing when each level was registered.
- The final CPA consistently dominated the critical path.

This behavior directly correlated with STA results and confirmed that CSA logic is amenable to deep pipelining, while the CPA is not.

### B. Discovery: Uniform Pipelining != Uniform Timing

A key realization from this iteration:

- All stages were fully registered.
- Each stage nominally had a full clock cycle.
- Despite this, timing violations persisted.

Root cause:
- Logic depth within a stage matters more than the presence of registers alone.
- The CPA’s carry propagation creates a serial dependency that consumes most of the cycle.
- Even with clean register boundaries, the CPA remained the slowest structure.

This explained why the design failed timing despite “correct” pipelining discipline.

### C. Concrete STA Evidence

Static timing analysis revealed a clear shift in the critical path:

- **Earlier expectation**:
  - CSA logic + routing + CPA combined
- **Observed post-CTS path**:
  - `r_stg3/Q → CPA → r_o_val/D`

Quantitative evidence:
- Worst negative slack improved from approximately **–0.71 ns** to **–0.50 ns** after architectural adjustments.
- The critical path consistently traversed specific carry-chain bits (e.g., `adder_b[8]`), confirming carry propagation dominance rather than random routing effects.

This provided a direct cause → effect link between RTL structure and STA results.

Additional observation:
- Introducing an extra pipeline register immediately before the final CPA improved slack, even though the CPA inputs were already driven by registers.
- This improvement came from reduced fanout, lower capacitive loading, and improved buffering and cell sizing around the CPA inputs, not from reduced logical depth.

This effect is ASIC-specific:
- In ASIC flows, register placement reshapes electrical load, wire length, and buffering decisions that directly impact timing.
- FPGA tools largely abstract these effects through fixed routing fabrics and pre-characterized arithmetic blocks, making such register duplication appear redundant.

### D. Architectural Conclusion: CPA Is a Different Class of Problem

This iteration established a fundamental distinction:

- CSA trees are **reduction structures**
  - Parallel
  - Scalable with depth
  - Well-suited to aggressive pipelining
- CPAs are **propagation structures**
  - Serial by nature
  - Frequency-limiting
  - Poorly mitigated by tool-level optimization alone

This marks the transition from RTL-level tuning to true architectural reasoning.

### E. Decision Space Moving Forward

Based on observed timing behavior, the valid architectural options are:

- Insert an additional pipeline stage within the final CPA
- Accept increased latency in exchange for timing closure
- Relax the clock target
- Explicitly reject the assumption that CTS or routing optimization will resolve CPA-dominated timing paths

These options define the constrained and realistic solution space for subsequent iterations.

### F. Signed Multiplication: Architectural Reality Check

During implementation, it became clear that signed multiplication is not a semantic attribute but an architectural one.

Initial multiplier structures were derived from unsigned partial-product generation and CSA reduction. While functionally correct for unsigned operands, extending this structure to signed arithmetic introduced:
   - Additional sign-extension logic
   - Conditional negation of MSB partial products
   - Baugh–Wooley-style correction terms

These modifications significantly increased logic depth and fanout in Stage-0, directly impacting timing.

A key learning was that signed-multiplier support must be treated as a first-class architectural decision, not a late-stage functional patch. Retrofitting signed behavior into an unsigned reduction tree complicates both timing closure and verification.

As a result, subsequent iterations temporarily constrained the multiplier to unsigned operation to isolate datapath timing behavior, with the intention of reintroducing signed support via a structurally correct, pipelined signed-multiplier architecture.