# Keccak or Ascon? — `hash_ise`
This branch adds a **shared scalar Instruction-Set Extension** that accelerates both Keccak-*f*[1600] and Ascon-*p* from inside the CVA6 pipeline. The extension (`hw/hash_ise`), operating through the Core-V eXtension Interface (CV-X-IF), introduces the following new instructions:

| Instr. | Format | Encoding | Operation |
|--------|--------|----------|-----------|
| `XOR3`   | R4 | `CUSTOM-1`, f2 = 10, f3 = 000 | rd = rs1 ⊕ rs2 ⊕ rs3 |
| `XANDN`  | R4 | `CUSTOM-1`, f2 = 10, f3 = 001 | rd = rs1 ⊕ (¬rs2 ∧ rs3) |
| `RXRI.L` | R4 | `CUSTOM-2`, n = f2‖f3 | rd = ROL(rs1 ⊕ rs2 ⊕ ROL(rs3, 1), n) |
| `RXRI.H` | R4 | `CUSTOM-3`, n = 32 + f2‖f3 | rd = ROL(rs1 ⊕ rs2 ⊕ ROL(rs3, 1), n) |
| `DRORX`  | I  | `CUSTOM-0`, imm = r1‖r2 | rd = rs1 ⊕ ROR(rs1, r1) ⊕ ROR(rs1, r2) |

## Quick Start
Fetch the Bender dependencies once, as initial setup:
```
make getdeps
```

Any of the tests below can then be simulated by name:
```
make run PROGRAM=<TEST_NAME> TIMEOUT=10000
```

| `TEST_NAME` | Backend | Measures |
|-----------|---------|----------|
| `hello_world`  | - | SoC Sanity Check |
| `keccak-shake128`  | Keccak | Cycle cost of one Keccak-*f*[1600] call, labelled with the SHAKE128 rate (r = 1344 bits) |
| `ascon-xof128`     | Ascon  | Cycle cost of one Ascon-p12 call, labelled with the Ascon-XOF128 rate (r = 64 bits) |
| `ascon`            | Ascon  | Ascon-p12 known-answer test against the NIST-LWC reference vectors |
| `ml-kem-512`       | Keccak | ML-KEM-512 key generation, encapsulation, decapsulation |
| `ml-dsa-2`         | Keccak | ML-DSA-44 key generation, signature, verification |
| `ml-kem-512-ascon` | Ascon  | ML-KEM-512 with Ascon-XOF128 replacing SHAKE/SHA-3 |
| `ml-dsa-2-ascon`   | Ascon  | ML-DSA-44 with Ascon-XOF128 replacing SHAKE/SHA-3 |


Results are reported on the console and collected under the `verif/out` directory.

## Writing Custom Programs
Place your program in the `sw` directory. Use the Hello World example `Makefile` as a reference for how to build it. Then run the `run` target from the top-level `Makefile`, passing your selected program as an argument.

Simulations using the UART with realistic baud rates are computationally expensive. To improve simulation performance, configure the UART divider to a high value (up to CLK_FREQ/16).

## FPGA Synthesis
To synthesize the SoC and generate a bitstream, run:

```bash
make fpga BOARD=cw305 # CW305 Artix-7 (xc7a100tftg256-2), used for the paper results
```

The bitstream and the build artifacts (utilization, timing and power reports) are written to `fpga/out/run-YYYY-MM-DD`. Currently, only Vivado is supported.

To add support for a new board:
1. Add a new board entry in `fpga/targets.mk`.
2. Define the target clock frequency, UART baud rate, and XDC constraints filename.
3. Add the corresponding XDC file to `fpga/constraints`.

Use the existing targets as the reference implementation.

## Uploading a Program

Once the board is programmed, software is loaded over the same UART through the Boot ROM. Compile your program first, and verify that the generated HEX file includes the `B007BABE` signature on the first line:

```bash
make -C sw/ml-kem-512 ACCEL=1
```

Then upload it with `upload.py`, passing the serial port the board enumerates as (`--baud` defaults to 115200, matching the FPGA targets):

```bash
python utils/upload.py --hex sw/ml-kem-512/build/mlkem512_accel.hex --port /dev/cu.usbserial-1310
```

Expected output should be similar to the following:
```
Waiting for BootROM (rst core to trigger)...
Sending handshake...
Waiting for response...
Upload started...
Upload complete, 360 bytes sent.
Waiting for core to jump to RAM...
Program output:
----------------------------------------

Hello, world!

----------------------------------------
```

# Licensing
Copyright 2026 (c) EDGE Group - Politecnico di Torino

This branch builds on [cva6_barebones](https://github.com/federunco/cva6_barebones), a minimal CVA6 SoC released under the Solderpad Hardware License version 2.1, and is distributed under the same terms. Refer to the upstream repository for the documentation of the base platform.

## Dependencies
The table below summarizes the main third-party dependencies and their corresponding licenses.
| Dependency | Version | License | 
|-|-|-|
| [cva6](https://github.com/openhwgroup/cva6) | upstream | SPHL v0.51 
| [axi](https://github.com/pulp-platform/axi) | 0.31.1 | SPHL v0.51 
| [register_interface](https://github.com/pulp-platform/register_interface) | 0.4.1 | SPHL v0.51 
| [axi2mem](https://github.com/pulp-platform/axi2mem/blob/master/axi2mem.sv) | upstream | SPHL v0.51 