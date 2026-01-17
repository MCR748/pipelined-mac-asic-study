# Architectural Learnings: Timing-Driven Design Rules for High-Frequency ASIC Datapaths

  - This document records timing-driven architectural constraints derived from iterative RTL development, synthesis, static timing analysis (STA), clock tree synthesis (CTS), routing, and post-place-and-route (post-PnR) analysis of a high-frequency MAC datapath implemented in Sky130.
  - These points are not conventional best practices or high-level summaries.
  - They are empirically derived constraints revealed through repeated timing failures and physical design feedback.
  - Each item represents a rule whose violation consistently resulted in timing non-closure.

## 1. Timing Is Determined by Path Topology, Not Functional Redundancy

- Static Timing Analysis(STA) evaluates paths of the form:
    ```
    launch flop → combinational logic → capture flop
    ```

- STA does not consider about:
    - The number of prior pipeline stages
    - Whether intermediate registers are functionally redundant

- Adding registers along the path:
    - Breaks combinational paths
    - Alters electrical loading, buffering, and routing characteristics
    - Resets clock-to-Q and setup timing budgets

- **Key rule**:
    - Registers do not accumulate timing margin
    - Registers terminate paths

- **NOTE** : Functional redundancy does not imply timing redundancy.

## 2. Back-to-Back Registers Are a Valid Timing Mechanism

- Placing a register immediately before a carry-propagate adder (CPA):
    - Allocates a full clock cycle to the CPA 
    - Reduces fanout on the launching register 
    - Improves buffering and cell sizing around the adder

- This remains effective even when:
    - Inputs are already registered upstream  
    - Logical depth is unchanged    
    - This approach reflects standard industrial practice, not a workaround.

## 3. Logical Optimizations Can Degrade Timing 

- Synthesis and logic optimization may:
    - Collapse adjacent logic 
    - Merge AOI/OAI structures 
    - Increase effective logic depth

- Such transformations can degrade timing, despite reduced RTL complexity.

- This is particularly problematic in:
    - Carry-save adder (CSA) trees
    - Prefix adders
    - Datapaths tightly coupled with control logic

- **Implication**:
    - Explicit, structurally clear RTL is preferable to aggressive logic minimization at high target frequencies.
---

## 4. FPGA Timing Intuition Does Not Translate to ASICs

- FPGA flows abstract or hide critical physical effects, including:
    - Dedicated hard carry chains 
    - Fixed and highly optimized routing resources 
    - Much of the underlying electrical loading and buffering behavior

- FPGA devices consist of pre-manufactured logic blocks and routing fabrics:
    - EDA tools primarily map, pack, and route logic into an already-defined physical architecture
    - Placement and routing choices are constrained by the fixed device topology

- ASIC flows expose physical reality explicitly:
    - Logic is synthesized into standard cells
    - Cells must be explicitly placed on silicon
    - Interconnect must be fully routed by the tools
    - Electrical effects (wire delay, capacitance, slew) directly dominate timing

- ASIC tools operate over a vast design space:
    - Placement and routing decisions materially affect timing outcomes
    - Small architectural or structural RTL changes can have large physical timing consequences

- **Result**: Design patterns that appear redundant or unnecessary in FPGA contexts are often mandatory for achieving ASIC timing closure

## 5. “Fully Pipelined” Has No Meaning Without Quantitative Bounds

- A design may be:
    - Fully registered    
    - Nominally pipelined 
    - Yet fail timing closure

- Per-stage timing depends on:
    - Combinational depth
    - Fanout
    - Routing distance
    - Electrical degradation across gates

- Registers alone do not guarantee timing feasibility.

## 6. CSA vs. CPA Is a Primary Architectural Choice

- Carry-Save Adders (CSA):
    - Operate in parallel
    - Are locally routed
    - Are naturally pipeline-friendly

- Carry-Propagate Adders (CPA):
    - Are serial in nature
    - Are carry-dominated
    - Typically limit maximum frequency

Treating CSAs and CPAs as interchangeable components with different speeds is architecturally incorrect.

##  7. Carry-Propagate Adders Do Not Support Opportunistic Pipelining

- Prefix adders (e.g., Brent–Kung) were evaluated incrementally rather than fully pipelined from the outset.
    - A non-pipelined implementation:
    - Failed timing at 500 MHz in Sky130
    - Exhibited less severe violations compared to other CPA architectures
    - Indicated better inherent structural balance, but still insufficient margin

- Partial and mid-tree pipelining:
    - Reduced critical path length incrementally
    - Improved timing relative to the unpipelined design
    - Still resulted in unstable or non-predictable timing closure
    - Suffered from electrical collapse of multiple logical levels into a single cycle

- Final architectural conclusion:
    - Incremental pipelining was inadequate for deterministic closure
    - Timing became predictable only when every prefix level was isolated by a register

- At 500 MHz in Sky130, the only consistently viable solution was:
    - One prefix level per cycle
    - Explicit valid signal alignment across stages
    - Explicit acceptance of increased adder latency

- This outcome was driven by physical timing behavior rather than logical correctness.

## 8. Wallace and CSA Trees Require Full Pipelining

- Grouping multiple CSA levels into a single cycle leads to:
    - Fanout escalation
    - Long horizontal routing paths
    - AOI/OAI gate collapse during optimization

- Observed safe constraint:
 - One CSA level per cycle

- Register placement directly reshapes:
    - Wire lengths
    - Capacitive loading
    - Buffer insertion patterns

## 9. Accumulators Are Loop-Carried Dependencies

- An accumulator is inherently recurrent and not feed-forward.

- The recurrence:
```
acc(n+1) = acc(n) + product(n)
```
- Pipelining the feedback path alters functional behavior.

- Any multi-cycle accumulator requires:
    - Stalling
    - Interleaving
    - Or explicit semantic redefinition

## 10. Carry-Save Accumulation Is Mandatory at High Frequency

- A single-cycle CPA in an accumulator feedback loop is incompatible with aggressive clock targets.

- A CSA-based accumulator:
    - Preserves recurrence semantics
    - Eliminates carry propagation from the loop
    - Reduces the feedback path to simple XOR/AND logic

- This is not an optimization choice; it is a structural requirement.

## 11. Canonicalization Must Be Decoupled from Accumulation

- Accumulation and observation are distinct operations.

- Binary (canonical) value generation:
    - Must occur outside the feedback loop
    - Can be arbitrarily pipelined
    - Can absorb additional latency without affecting correctness

## 12. Control Logic Near Arithmetic Is Bad to Timing

- Gating arithmetic registers with valid signals:
    - Synthesizes into muxes and AOI/OAI structures
    - Degrades arithmetic input timing

- Control fanout can dominate arithmetic delay.

- Preferred pattern:
    - Arithmetic operates every cycle
    - Invalid cycles inject zero-valued operands
    - Arithmetic state is never conditionally gated

## 13. STA Is an Iterative Design Instrument

- STA failures evolve during the design process:
    - Early failures expose architectural deficiencies
    - Late failures reveal physical and electrical limits

- Once STA ceases to provide new architectural insight, the architecture is effectively finalized.

## 14. Post-PnR Timing Failure Indicates Physical Limits

- Pre-PnR timing success is not predictive.

- Post-PnR analysis exposes:
    - Wire-delay dominance
    - Slew violations
    - Clock uncertainty

- At this stage:
    - Architectural restructuring options are exhausted
    - Remaining levers are clock frequency, floorplanning, or technology selection

## 15. Final Observation

- Timing closure is not achieved through cleverness.

- It requires strict adherence to:
    - Logical dependencies
    - Electrical constraints
    - Temporal boundaries
