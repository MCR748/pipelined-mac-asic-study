## Toolchain Execution Model

This project uses LibreLane’s officially supported Dockerized execution mode.

LibreLane is executed with the `--dockerized` flag, which launches a version-locked Docker environment containing the full ASIC toolchain.

The setup was validated using the official LibreLane smoke test prior to RTL development.

## LibreLane Installation (Dockerized)

LibreLane is installed inside a user-managed Python virtual environment and executed in Dockerized mode.

Virtual environment setup and installation:

  ```bash
  python3 -m venv librelane-venv
  source librelane-venv/bin/activate
  pip install librelane
  ```
  
Validation
  ```bash
  librelane --dockerized --smoke-test
  ```

## Simulation (Non-Signoff)

RTL simulation is performed outside the LibreLane Docker environment using a locally installed cycle-accurate simulator (Verilator).

Simulation is used exclusively for:
- Functional validation of RTL behavior.
- Verification of pipeline latency and reset semantics.
- Early detection of semantic mismatches prior to synthesis.

The simulation toolchain is intentionally not version-pinned (uses v4.106 at the time of writing), as it does not affect ASIC flow reproducibility.

## Project Path and Docker Mounting Assumptions

- LibreLane’s Dockerized execution model assumes that all design files referenced by the configuration are visible inside the container through predefined host directory mounts.
- During initial setup, attempts to run LibreLane on a project located outside the default mounted paths resulted in configuration file resolution failures, despite correct host-side paths.
- To align with LibreLane’s intended execution model and avoid reliance on custom Docker mount overrides, the project directory was placed under the user home directory, which is mounted by default into the container.

As a result:
  - All paths referenced in config.json are valid both on the host and inside the container.
  - The LibreLane invocation does not require additional Docker mount configuration.
  - The flow can be reproduced without environment-specific adjustments.