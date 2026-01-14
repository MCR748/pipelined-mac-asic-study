## Toolchain Execution Model

This project uses LibreLane’s officially supported Dockerized execution mode.

LibreLane is executed with the `--dockerized` flag, which launches a version-locked Docker environment containing the full ASIC toolchain.

The setup was validated using the official LibreLane smoke test prior to RTL development.

## Toolchain Execution Model

This project uses LibreLane’s officially supported Dockerized execution mode.

LibreLane is executed with the `--dockerized` flag, which launches a version-locked Docker
environment containing the full ASIC toolchain.

The setup was validated using the official LibreLane smoke test prior to RTL development.

## LibreLane Installation (Dockerized)

LibreLane is installed inside a user-managed Python virtual environment and executed in
Dockerized mode.

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
