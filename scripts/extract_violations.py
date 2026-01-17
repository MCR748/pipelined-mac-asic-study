#!/usr/bin/env python3
import re
import glob
import os
import csv

BASE_DIR = "/home/mcrparadox/work/MAC/flow/librelane/mac_stage1/runs"
EXTRACT_BASE = "/home/mcrparadox/work/MAC/flow/librelane/mac_stage1/extracts"

# ------------------------------------------------------------
# Find latest RUN directory
# ------------------------------------------------------------
run_dirs = sorted(
    glob.glob(os.path.join(BASE_DIR, "RUN_*")),
    key=os.path.getmtime
)

if not run_dirs:
    raise RuntimeError("No RUN_* directories found")

latest_run = run_dirs[-1]
run_name = os.path.basename(latest_run)

rpt_path = os.path.join(
    latest_run,
    "54-openroad-stapostpnr",
    "max_ss_100C_1v60",
    "max.rpt"
)

netlist_path = os.path.join(
    latest_run,
    "06-yosys-synthesis",
    "mac_top.nl.v"
)

if not os.path.isfile(rpt_path):
    raise RuntimeError(f"Report not found: {rpt_path}")

if not os.path.isfile(netlist_path):
    raise RuntimeError(f"Netlist not found: {netlist_path}")

# ------------------------------------------------------------
# Prepare extract directory
# ------------------------------------------------------------
extract_dir = os.path.join(EXTRACT_BASE, run_name)
os.makedirs(extract_dir, exist_ok=True)

csv_path = os.path.join(extract_dir, "max_ss_violations.csv")

# ------------------------------------------------------------
# Parse netlist: map FF instance → Q signal
# ------------------------------------------------------------
ff_q_map = {}

with open(netlist_path) as f:
    text = f.read()

ff_re = re.compile(
    r"sky130_fd_sc_hd__dfxtp_\d+\s+(_\d+_)\s*\((.*?)\);",
    re.S
)

for inst, body in ff_re.findall(text):
    q_match = re.search(r"\.Q\(\s*\\?([^\s\)]+)", body)
    if q_match:
        ff_q_map[inst] = q_match.group(1)

# ------------------------------------------------------------
# Parse timing report
# ------------------------------------------------------------
with open(rpt_path) as f:
    lines = f.readlines()

results = []

endpoint = None
start_signal = None
after_q = False
in_path = False

for line in lines:
    if line.startswith("Startpoint:"):
        endpoint = None
        start_signal = None
        after_q = False
        in_path = True
        continue

    if not in_path:
        continue

    m = re.search(r"Endpoint:\s+(\S+)", line)
    if m:
        endpoint = m.group(1)

    if re.search(r"/Q\s+\(sky130_fd_sc_hd__dfxtp", line):
        after_q = True
        continue

    if after_q and start_signal is None:
        m = re.search(r"\s+([a-zA-Z0-9_.\[\]]+)\s+\(net\)", line)
        if m:
            start_signal = m.group(1)
            after_q = False

    m = re.search(r"\s+([\-0-9.]+)\s+slack\s+\(VIOLATED\)", line)
    if m:
        slack = float(m.group(1))
        end_name = ff_q_map.get(endpoint, endpoint)
        if start_signal:
            results.append((start_signal, end_name, slack))
        in_path = False

# ------------------------------------------------------------
# Write CSV
# ------------------------------------------------------------
with open(csv_path, "w", newline="") as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(["start_signal", "end_signal", "slack"])
    for row in results:
        writer.writerow(row)

# ------------------------------------------------------------
# Optional stdout summary
# ------------------------------------------------------------
print(f"# Latest run: {run_name}")
print(f"# Written to: {csv_path}")
print("start_signal,end_signal,slack")

for s, e, sl in results:
    print(f"{s},{e},{sl}")
