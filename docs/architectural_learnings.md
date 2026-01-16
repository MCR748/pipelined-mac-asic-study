# Architectural Learnings: Timing-Driven Design Rules for High-Frequency ASIC Datapaths

This document captures a set of **non-obvious, timing-driven architectural rules** derived from iterative RTL design, synthesis, STA, CTS, routing, and post-PnR analysis of a high-frequency MAC datapath in Sky130.

These are **not summaries** and **not best practices by convention**.  
They are **hard constraints** revealed by static timing analysis and physical design reality.

Each point represents a rule that, if violated, predictably resulted in timing failure.

---

## 1. Timing Is About Path Topology, Not Functional Redundancy  

Static Timing Analysis (STA) evaluates only the following construct:
```
launch flop → combinational logic → capture flop
```

STA does **not** care about:
- How many registers a signal passed earlier
- Whether a register is “functionally redundant”

Adding a back-to-back register:
- Cuts the combinational path
- Resets clock-to-Q and setup time budgets
- Reshapes electrical loading, buffering, and routing

**Key rule:**

> Registers don’t “store time”.  
> They **cut paths**.

Functionally redundant ≠ timing redundant.

---

## 2. Back-to-Back Registers Are a Legitimate Timing Tool  

Adding a register immediately before a carry-propagate adder (CPA):

- Gives the CPA a full clock cycle
- Reduces fanout on the launch flop
- Improves buffering and cell sizing around the adder

This is effective even if:
- Inputs were already registered earlier
- Logical depth is unchanged

This is **standard industrial practice**, not a hack or workaround.

---

## 3. Tools Can Make Timing Worse by Being “Helpful”  

Synthesis and optimization can:
- Collapse adjacent logic
- Merge AOI/OAI structures
- Increase effective logic depth

This can **worsen timing**, even when the RTL appears simpler.

Especially dangerous in:
- CSA trees
- Prefix adders
- Control-adjacent datapaths

**Implication:**

> Clean, explicit RTL structure beats “clever” logic minimization at high frequency.

---

## 4. FPGA Timing Intuition Is Actively Misleading  

FPGA tools hide:
- Carry chains
- Routing delay
- Electrical loading

ASIC flows expose all of it.

What feels “redundant” in FPGA design is often **mandatory** for ASIC timing closure.

---

## 5. “Fully Pipelined” Is a Useless Phrase Without Bounds

A design can be:
- Fully registered
- Fully pipelined
- And still fail timing badly

What actually matters per pipeline stage:
- Logic depth
- Fanout
- Routing span
- Electrical collapse across gates

Registers alone do not guarantee timing safety.

---

## 6. CSA vs CPA Is a First-Order Architectural Decision

Carry-Save Adders (CSA):
- Parallel
- Local
- Pipeline-friendly

Carry-Propagate Adders (CPA):
- Serial
- Carry-dominated
- Frequency-limiting

Treating CSAs and CPAs as “the same but faster” is architecturally incorrect.

---

## 7. CPAs Do Not Tolerate Partial Pipelining

Prefix adders (including Brent–Kung):
- Fail with opportunistic or mid-tree pipelining
- Collapse multiple logical levels electrically into one cycle

The only working solution at 500 MHz in Sky130:
- One prefix level per cycle
- Explicit valid alignment
- Latency explicitly accepted

---

## 8. Wallace / CSA Trees Must Be Fully Pipelined

Grouping multiple CSA levels per cycle causes:
- Fanout explosion
- Long horizontal routing
- AOI/OAI gate collapse

Safe bound:
- **One CSA level per cycle**

Register placement reshapes:
- Wire length
- Capacitive load
- Buffer topology

---

## 9. Accumulators Are Loop-Carried Dependencies  

An accumulator is **not** a feed-forward adder.

Pipelining accumulator feedback breaks MAC semantics:
```
acc(n+1) = acc(n) + product(n)
```

Any multi-cycle accumulator requires:
- Stalling
- Interleaving
- Or semantic redefinition

---

## 10. Carry-Save Accumulation Is Mandatory at High Frequency

A single-cycle CPA in the feedback loop is:
- Fundamentally incompatible with aggressive clocks

A CSA-based accumulator:
- Preserves recurrence semantics
- Eliminates carry propagation from the loop
- Reduces the feedback path to XOR/AND logic

This is **not an optimization** — it is a requirement.

---

## 11. Canonicalization Must Be Outside the Loop

Accumulation ≠ observation.

Binary (canonical) value generation:
- Must be outside the feedback loop
- Can be pipelined arbitrarily
- May absorb latency freely

---

## 12. Control Logic Is Toxic Near Arithmetic

Gating arithmetic registers with `valid`:
- Synthesizes into muxes and AOI/OAI logic
- Pollutes arithmetic D-input timing

Control fanout can dominate arithmetic delay.

Correct pattern:
- Arithmetic runs every cycle
- Zero-inject operands on invalid cycles
- Never gate arithmetic state

---

## 13. STA Is a Design Instrument, Not a Report

STA failures evolve over time:
- Early failures → architectural diagnosis
- Late failures → physical feasibility limits

When STA stops teaching new architectural lessons, the architecture is complete.

---

## 14. Post-PnR Failure Can Mean “You’re at the Limit”

Passing pre-PnR proves nothing.

Post-PnR exposed:
- Wire delay dominance
- Slew limits
- Clock uncertainty

At this stage:
- Arithmetic restructuring is exhausted
- Remaining knobs are frequency, floorplan, or technology

---

## 15. Final Hard Truth

Timing closure is not about being clever.

It is about respecting dependencies —  
**logical, electrical, and temporal**.
