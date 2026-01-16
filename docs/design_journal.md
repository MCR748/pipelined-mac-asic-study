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

## Iteration 2 (Continued) – Prefix Adder and Wallace Tree: Full-Pipeline Necessity

This subsection records the architectural conclusions reached after repeated attempts to close timing on both the carry-propagate adder (CPA) and the multiplier reduction tree under worst-case PVT conditions.

---

## G. Brent–Kung Adder: Mid-Tree Pipelining Attempt and Failure

Following identification of the CPA as the dominant timing limiter, the final adder was reimplemented as a Brent–Kung parallel prefix adder, selected for its reduced logic depth compared to ripple carry and lower wiring complexity compared to Kogge–Stone.

### Initial Hypothesis

It was hypothesized that:

- A Brent–Kung structure, combined with selective mid-tree pipelining, would be sufficient to meet the 500 MHz target.
- Inserting registers at timing-identified internal prefix levels (e.g., between level-2 and level-3) would bound per-cycle logic depth.
- Tools would balance remaining prefix logic through buffering and cell upsizing.

### Implementation Strategy

- Generate/propagate (p/g) signals were registered.
- Prefix tree levels were constructed incrementally.
- Pipeline registers were inserted inside the Brent–Kung tree at locations suggested by STA critical paths.
- Valid signals were propagated alongside prefix data to preserve functional alignment.

### Observed Outcome

Despite these measures:

- Timing closure failed at worst-case corners, most notably `max_ss_100C_1v60`.
- STA consistently reported violations inside prefix logic feeding intermediate generate nodes (e.g., `gn3[*]`), even when earlier levels were registered.
- Incremental pipelining reduced slack marginally but did not eliminate violations.

### Key Insight

This demonstrated that:

- Partial or opportunistic pipelining of a propagation structure is insufficient under aggressive frequency targets.
- Even though each prefix level was logically shallow, electrical reality—fanout, wire length, and AOI/OAI gate collapse—caused multiple prefix levels to be effectively traversed within a single cycle.
- This invalidated the assumption that a “mostly pipelined” prefix adder is adequate for 500 MHz in Sky130.

---

## H. Architectural Resolution: Fully Pipelined Prefix Adder

The Brent–Kung adder was ultimately restructured into a fully pipelined prefix network, with:

- One prefix-combine level per pipeline stage
- Registers inserted between every prefix level
- Explicit valid propagation through all stages
- Final carry generation and sum XOR isolated in their own registered stage

This resulted in:

- Increased latency
- Stable timing closure across worst-case corners
- Predictable and bounded per-stage logic depth

This confirmed a critical architectural rule:

> At aggressive clock targets, propagation structures (CPAs) must be pipelined at every logical depth, not merely at “convenient” boundaries.

---

## I. Wallace / CSA Tree: Secondary Timing Bottleneck

After stabilizing the CPA, attention returned to the multiplier’s Wallace reduction tree.

### Initial CSA Strategy

- A classical Wallace-style reduction was implemented using carry-save adders (CSAs).
- Multiple CSA levels were grouped between pipeline registers (e.g., one register after every two CSA layers).
- This structure was expected to be timing-safe due to the local nature of CSA logic.

### Observed Timing Behavior

STA revealed that:

- While individual CSAs are shallow, grouping multiple CSA stages per cycle created:
  - Large fanout on intermediate sum/carry buses
  - Long horizontal routes due to wide operand buses
  - AOI/OAI gate collapse across CSA boundaries
- Timing violations emerged inside the CSA tree, independent of the final CPA.
- These violations were not random:
  - They consistently appeared in later CSA stages where operand width and routing span were largest.
- Post-CTS timing degraded further due to clock skew and wire delay, confirming the structural nature of the issue.

---

## J. Architectural Resolution: Fully Pipelined Wallace Tree

To resolve this, the Wallace tree was restructured to be fully pipelined, with:

- Exactly one CSA reduction level per cycle
- Explicit registers between every CSA stage
- Carry shifting performed outside the CSA itself
- Valid propagation aligned stage-by-stage

This eliminated:

- Multi-level CSA logic in a single cycle
- Wide reconvergent paths
- Unbounded routing delay within a stage

The resulting structure mirrors industrial high-frequency multipliers:

- Deep pipeline
- High throughput (1 result per cycle)
- Latency traded explicitly for frequency

---

## K. Consolidated Architectural Learning

This iteration establishes several non-negotiable principles for high-frequency ASIC datapaths:

- Propagation structures (CPAs) and reduction structures (CSAs) behave fundamentally differently
- CSAs scale well with pipelining
- CPAs do not tolerate partial pipelining
- “Fully registered” does not imply “timing-safe”
- Logic depth within a stage remains the dominant factor
- Register placement reshapes electrical and routing behavior
- Worst-case PVT corners dictate architecture
- Designs that nearly pass at typical corners will fail catastrophically at SS / high temperature
- Architectural decisions must be justified at worst case, not average case
- FPGA intuition is actively misleading for ASIC timing
- Fixed carry chains and abstracted routing hide effects that dominate ASIC performance
- Deep, explicit pipelining is unavoidable at aggressive frequencies

---

## Current State of Iteration 2

- Both the Wallace reduction tree and Brent–Kung CPA are fully pipelined.
- Timing closure is achieved through architectural means, not tool-level optimization.
- Latency is increased but explicitly managed.
- The datapath is now suitable as a stable foundation for:
  - Signed arithmetic reintroduction
  - Accumulation feedback
  - Control-plane integration

This reflects the current structurally timing-clean state of Iteration 2, with further extensions planned on top of a verified high-frequency datapath.

## Iteration 3 – Stage 1B (Extended): Post-PnR Timing Reality and Worst-Case Closure Limits

This iteration records the results obtained after running the **full LibreLane ASIC flow** (synthesis → CTS → routing → post-route STA) on the Stage 1B design incorporating a CSA-based accumulator and a Brent–Kung canonicalization adder.

The purpose of this iteration is to reconcile **architectural correctness** with **worst-case silicon feasibility**, rather than to claim unconditional timing closure.

---

### A. Full-Flow Execution Outcome

The complete LibreLane flow finished successfully through manufacturability checks:

- All physical design stages completed  
- Layout and routing were generated  
- Reports were produced for STA, routing, and manufacturability  

However, the flow issued **explicit warnings** indicating unresolved timing and signal-integrity issues at worst-case corners.

---

### B. Timing Results Summary

**Clock Target:** 500 MHz (2.0 ns)

**Corner Analysis:**

| Corner | Result |
|------|------|
| Typical | **Pass** |
| Nominal SS @ 100 °C | **Fail** |
| Worst-case SS @ 100 °C, 1.60 V | **Fail** |

Reported by LibreLane checkers:

- Setup violations at:
  - `max_ss_100C_1v60`
  - `min_ss_100C_1v60`
  - `nom_ss_100C_1v60`
- Max slew violations at:
  - `max_ss_100C_1v60`
- Post-CTS resizer unable to repair all setup violations

This confirms that **architectural fixes alone were insufficient to guarantee worst-case closure at 500 MHz**, even though the design is functionally and structurally correct.

---

### C. Interpretation of the Result

These results are **not contradictory** to the architectural conclusions of Stage 1B. Instead, they refine them:

- The CSA-based accumulator **eliminated feedback-loop carry propagation**
- Control-path removal **eliminated false critical paths**
- The remaining violations arise from:
  - Wire delay  
  - Fanout  
  - Slew limits  
  - Post-CTS clock uncertainty  
  - Worst-case PVT pessimism  

The design now fails for **physical reasons**, not **conceptual or structural errors**.

This marks a critical transition:

> Timing failure is no longer diagnostic of architectural mistakes, but of **technology and frequency limits**.

---

### D. Key Observations from Post-PnR Reports

- Large nets (200+ pins) were flagged as routing risks, indicating datapath width pressure.
- Slew violations appeared only in worst-case corners, reinforcing that:
  - The design is near the edge of feasibility  
  - Minor electrical effects dominate at this point  
- No functional or semantic violations were observed during simulation.

---

### E. Architectural Implication

At this stage, the remaining options to close worst-case timing are **non-architectural**:

- Reduce target frequency  
- Introduce additional pipeline stages (latency increase)  
- Apply physical optimization strategies:
  - Net restructuring  
  - Register duplication  
  - Floorplanning constraints  
- Accept typical-corner operation as the design point  

Crucially, **no further arithmetic restructuring is justified**.

---

## Iteration 2 (Continued) – Stage 1B: Accumulator Feedback and Timing Reality

This subsection records the architectural lessons that emerged while introducing accumulation feedback on top of a timing-clean, fully pipelined multiplier datapath.

The intent of this stage was to transform the multiplier into a true MAC by adding an accumulator, while preserving the aggressive 500 MHz target under worst-case PVT conditions.

---

### L. Initial Assumption: Accumulator as a Carry-Propagate Adder

#### Hypothesis

The accumulator could be implemented as a conventional carry-propagate adder (CPA) with pipelining applied internally if required, similar to the treatment of the final multiplier adder.

#### Observation

This assumption failed immediately under sustained valid input.

A pipelined accumulator violates the fundamental recurrence:
  ```
  acc(n+1) = acc(n) + product(n)
  ```

Introducing latency inside the feedback loop caused:

- Accumulator state to lag behind incoming products  
- Semantic mismatch between mathematical intent and RTL behavior  
- Incorrect accumulation under continuous operation  

#### Conclusion

An accumulator cannot be multi-cycle unless additional architectural mechanisms are introduced (stalling, interleaving, or windowed reduction).

For a true MAC, the accumulation recurrence must complete in a single architectural cycle.

This invalidated the use of a pipelined CPA inside the accumulator feedback path.

---

### M. Accumulator Timing Bottleneck at 500 MHz

#### Empirical STA Findings

When implemented as a single-cycle CPA:

- The accumulator feedback path became the dominant critical path:
```
acc_reg/Q → CPA → acc_reg/D
```

Even with a Brent–Kung adder:

- Worst-case slack remained negative at SS / 100 °C  
- Violations persisted post-CTS and post-route  
- Critical paths consistently traversed carry-dependent bit positions  

#### Key Insight

The accumulator is not just another adder—it is a loop-carried dependency.

Unlike feed-forward datapaths, it cannot amortize carry propagation across cycles.

This placed the accumulator in a fundamentally different timing class from the multiplier.

---

### N. Architectural Resolution: Carry-Save Accumulator (CSA-Based)

To satisfy both correctness and timing constraints, the accumulator was restructured as a carry-save accumulator.

Two state registers are maintained:

- `acc_sum`  
- `acc_carry`  

Each cycle performs carry-save addition:
```
{acc_sum, acc_carry} = acc_sum + acc_carry + product
```

No carry propagation occurs in the feedback loop.

Only local XOR/AND logic is exercised per bit.

#### Result

- Loop-carried dependency preserved semantically  
- Critical path reduced to CSA logic only  
- Accumulation meets 500 MHz timing in Sky130 HD (pre-PnR)  

This established a non-negotiable rule:

> At aggressive clock targets, accumulator feedback must be carry-save.

---

### O. Canonicalization via Brent–Kung Adder (Outside the Loop)

While CSA state is sufficient for accumulation, it is not directly observable as a numerical result.

To produce a canonical output:

- A Brent–Kung carry-propagate adder is applied after the accumulator  

This CPA:

- Is not part of the feedback loop  
- May be fully pipelined  
- Trades latency for timing closure  

Canonicalization is treated as a read operation, not part of accumulation semantics.

This separation allows:

- Correct MAC behavior  
- High-frequency operation  
- Controlled placement of expensive carry propagation  

---

### P. Control vs Datapath Separation: Timing-Driven Discovery

#### Observed Failure Mode

Initial accumulator implementations gated CSA state updates using a valid signal.

As synthesized:

- Valid gating became data-path muxing  
- Control logic (AND / OR / OAI) appeared on accumulator D-inputs  

STA exposed paths such as:
```
mul_valid → control logic → acc_carry[D]
```

#### Consequence

- Control signals polluted arithmetic timing paths  
- Small control fanout delays dominated the critical path  
- Timing failed despite shallow arithmetic logic  

#### Resolution

- Control signals were removed from arithmetic state updates  
- Invalid cycles inject a zero operand instead of gating registers  
- Accumulator state updates every cycle unconditionally  

#### Architectural Rule Established

Control and datapath must be structurally separated in high-frequency designs.

Control should select operands, not gate arithmetic state.

---

### Q. Consolidated Learnings from Stage 1B

This stage established two critical architectural facts:

#### 1. Accumulators Cannot Be Multi-Cycle

- A pipelined accumulator violates MAC semantics  
- Loop-carried dependencies must complete in one architectural cycle  
- Carry-save accumulation is the only scalable solution at high frequency  

#### 2. Datapath and Control Must Be Isolated

- Control gating on arithmetic registers creates hidden critical paths  
- Valid signals must not participate in arithmetic feedback  
- Zero-injection is preferable to register enable gating  

These conclusions were enforced by STA evidence under worst-case PVT conditions.

---

### Status After Stage 1B

- Accumulator feedback path is architecturally timing-clean  
- CSA used for accumulation  
- Brent–Kung used only for canonicalization  
- Control logic removed from arithmetic state paths  
- Remaining timing failures are physical, not structural  

This completes Stage 1B and provides a structurally sound foundation for:

- Signed arithmetic integration (Stage 1C)  
- Control-plane attachment (Stage 2)  


# Phase Closure – End of Unsigned MAC Architectural Exploration

This section marks the deliberate conclusion of the current design phase, which focused on **unsigned multiplication, accumulator feedback, and aggressive frequency exploration** under Sky130 worst-case PVT conditions.

The goal of this phase was **not** to achieve unconditional timing closure, but to:
- Expose architectural limits
- Identify non-negotiable timing rules
- Separate structural correctness from physical feasibility

That objective has been met.

---

## A. Known Outstanding Issues at Phase End

The following limitations are explicitly acknowledged at the end of this phase:

### 1. Multiplier Is Unsigned

- The current datapath implements an **unsigned multiplier only**
- Signed arithmetic was intentionally deferred to avoid conflating:
  - Sign-handling complexity
  - Partial-product correction logic
  - And accumulator feedback timing
- As a result, functional completeness for signed MAC operation is **not yet achieved**

This is a known and accepted limitation of the current implementation.

---

### 2. Wallace / CSA Tree Still Violates Worst-Case Timing

- Despite full pipelining, the Wallace reduction tree:
  - Exhibits timing violations at worst-case SS / high-temperature corners
  - Is sensitive to routing span and fanout in later CSA stages
- These violations persist post-CTS and post-route

This indicates that the design is approaching **physical feasibility limits** for:
- Operand width
- Clock target
- Technology (Sky130)

No further structural changes within the same architectural envelope are expected to resolve this.

---

### 3. CSA-Based Accumulator Still Fails at Worst-Case Corners

- The accumulator architecture is **structurally correct**:
  - Carry-save feedback
  - No carry propagation in the loop
  - Control-path separation enforced
- However, worst-case STA still reports violations due to:
  - Wire delay
  - Fanout
  - Slew constraints
  - Post-CTS clock uncertainty

This confirms that remaining failures are **physical**, not conceptual.

---

## B. Interpretation of These Failures

These issues do **not** invalidate the architectural conclusions reached so far.

Instead, they establish an important boundary:

> The current unsigned MAC architecture is structurally correct,  
> but exceeds the reliable worst-case operating envelope at 500 MHz in Sky130.

At this point:
- Arithmetic restructuring has been exhausted
- Further progress requires **scope redefinition**, not iteration within the same scope

---

## C. Rationale for Ending This Phase

Continuing iteration within the current constraints would:
- Produce diminishing architectural insight
- Blur the distinction between structural issues and technology limits
- Obscure the learning objectives of the project

Therefore, this phase is intentionally concluded.

---

## D. Defined Next Phase Objectives

The next phase will proceed with **explicitly revised goals**:

### Phase 2 – Signed Arithmetic and Accumulator Timing Closure

Primary objectives:

1. **Introduce a Signed Multiplier as a First-Class Architecture**
   - Redesign partial-product generation for signed operands
   - Incorporate sign correction (e.g., Baugh–Wooley or equivalent)
   - Re-pipeline Stage-0 logic as required
   - Quantify the timing and area cost of signed arithmetic

2. **Revisit Accumulator Timing with a Narrower Focus**
   - Re-evaluate CSA accumulator under signed operation
   - Explore:
     - Register duplication
     - Net restructuring
     - Floorplanning-aware constraints
   - Determine whether worst-case closure is achievable without:
     - Frequency reduction, or
     - Additional latency

3. **Explicitly Reframe Success Criteria**
   - Success will be defined as:
     - Architectural clarity
     - Worst-case explainability
     - Or an explicit declaration of infeasibility at the chosen frequency

---

## E. Phase Transition Statement

This concludes the **Unsigned MAC Architectural Exploration Phase**.

All subsequent work will be recorded under a new phase with revised assumptions, clearer feasibility boundaries, and narrower objectives.


