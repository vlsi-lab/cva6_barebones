# Keccak or Ascon? — A RISC-V Design-Space Exploration for ML-KEM and ML-DSA Workloads
This repository contains the RTL implementations for **Keccak or Ascon? — A RISC-V Design-Space Exploration for ML-KEM and ML-DSA Workloads**

This work compares pure software schemes with dedicated accelerators for Keccak-f[1600] and Ascon-p, and introduces a unified acceleration architecture that supports both permutations through a single shared execution unit integrated into the processor pipeline.

---

## Project Structure
Each acceleration strategy lives on its own branch of this repository. All branches share the same SoC skeleton, build flow, and software interface, so that the three design points can be compared under equivalent integration conditions.

| Variant | Branch | Description |
|---------|--------|-------------|
| Shared ISE | [`hash_ise`](../../tree/hash_ise) | Shared scalar Instruction-Set Extension integrated directly into the pipeline |
| Loosely coupled Keccak | [`keccak_loosely`](../../tree/keccak_loosely) | Keccak-f[1600] hardware accellerator |
| Loosely coupled Ascon | [`ascon_loosely`](../../tree/ascon_loosely) | Ascon-p hardware accellerator |

The `main` branch collects the prebuilt bitstreams for the CW305 Artix-7 board (`xc7a100tftg256-2`).

---
### Requirements

* Python 3 with `hjson`, `mako`, `tabulate` and `pyserial`
* [Bender](https://github.com/pulp-platform/bender)
* RISC-V GCC toolchain (RV64)
* Verilator (simulation) and Vivado (FPGA flow)

## Getting Started

Check out the branch matching the design point you want to evaluate:

```bash
git clone git@github.com:edge-group-polito/keccak_or_ascon.git
cd keccak_or_ascon
git checkout hash_ise # keccak_loosely / ascon_loosely
```

### Simulation

```bash
# Fetch the Bender dependencies (first time only)
make getdeps

# Run a program on the SoC testbench
make run PROGRAM=<TEST_NAME> TIMEOUT=10000
```

Results appear on the console and under `verif/out`. The cryptographic tests available are:

| `<TEST_NAME>` | Backend | Measures | `hash_ise` | `keccak_loosely` | `ascon_loosely` |
|---------------|---------|----------|:----------:|:----------------:|:---------------:|
| `keccak-shake128`  | Keccak | Cycle cost of one Keccak-f[1600] call| ✅ | ✅ | — |
| `ascon-xof128`     | Ascon  | Cycle cost of one Ascon-p12 call | ✅ | — | ✅ |
| `ascon`            | Ascon  | Ascon-p12 KAT against the NIST-LWC reference vectors | ✅ | — | ✅ |
| `ml-kem-512`       | Keccak | ML-KEM-512 key generation, encapsulation, decapsulation | ✅ | ✅ | — |
| `ml-dsa-2`         | Keccak | ML-DSA-44 key generation, signature, verification | ✅ | ✅ | — |
| `ml-kem-512-ascon` | Ascon  | ML-KEM-512 with Ascon-XOF128 replacing SHAKE/SHA-3 | ✅ | — | ✅ |
| `ml-dsa-2-ascon`   | Ascon  | ML-DSA-44 with Ascon-XOF128 replacing SHAKE/SHA-3 | ✅ | — | ✅ |

Every test builds in two flavours, so that the software baseline and the accelerated run come from the same source. Acceleration is off by default:

```bash
# Software baseline (RV64 base ISA)
make run PROGRAM=ml-kem-512 TIMEOUT=10000

make run PROGRAM=ml-kem-512 TIMEOUT=10000 ACCEL=1
```

Refer to each branch's own `README.md` for the full SoC documentation, FPGA build flow and the UART bootloader upload.

---

## Citation

If you use or build upon the work in these branches, please cite:

> Federico Runco, Valeria Piscopo, Enrico Manfredi, Alessandra Dolmeta, Maurizio Martina, and Guido Masera. **"Keccak or Ascon? A RISC-V Design-Space Exploration for ML-KEM and ML-DSA Workloads."**, 2026. *(DOI to be added)*

---

## Authors

* **Federico Runco** — federico.runco@polito.it
* **Valeria Piscopo** — valeria.piscopo@polito.it
* **Enrico Manfredi** — enrico.manfredi@polito.it
* **Alessandra Dolmeta** — alessandra.dolmeta@polito.it

---

## License
This work is released under the Solderpad Hardware License version 2.1, a permissive license based on Apache 2.0. Please refer to the license files on each branch for more information. Third-party dependencies retain the licensing terms of their respective upstream projects; cryptographic software follows the licensing of the reference implementations used as a starting point.
