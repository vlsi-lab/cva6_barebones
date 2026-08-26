# Copyright 2026 Federico Runco (federico.runco@gmail.com)
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
# 
# Licensed under the Solderpad Hardware License v2.1 (the “License”); 
# you may not use this file except in compliance with the License, or, 
# at your option, the Apache License version 2.0. You may obtain a copy 
# of the License at https://solderpad.org/licenses/SHL-2.1/
# 
# Unless required by applicable law or agreed to in writing, any work 
# distributed under the License is distributed on an “AS IS” BASIS, WITHOUT 
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
# License for the specific language governing permissions and limitations 
# under the License.

import argparse
import sys
import time
from pathlib import Path

import serial

def main():
    parser = argparse.ArgumentParser(description="CVA6 Barebones uploader")
    parser.add_argument("--hex", required=True, help="Input HEX file")
    parser.add_argument("--port", required=True, help="Device serial port")
    parser.add_argument("--baud", type=int, default=115200, help="Baudrate used for program upload")
    parser.add_argument("--timeout", type=float, default=5.0, help="Handshake timeout in seconds")
    parser.add_argument("--prg-timeout", type=float, default=5.0, help="Seconds to keep reading UART after JMP until idle")
    args = parser.parse_args()

    hex_path = Path(args.hex)
    if not hex_path.exists():
        raise FileNotFoundError(f"HEX file not found: {hex_path}")

    payloads = load_firmware(hex_path)

    with serial.Serial(args.port, args.baud, timeout=0.1) as ser:
        print("Waiting for BootROM (rst core to trigger)...")
        wait_for_string(ser, "BOOTRDY", args.timeout)

        print("Sending handshake...")
        ser.write(payloads[0])
        flush(ser)

        print("Waiting for response...")
        wait_for_string(ser, "UPLDRDY", args.timeout)
        
        print("Upload started...")
        total_bytes = len(payloads[0])
        for payload in payloads[1:]:
            ser.write(payload)
            total_bytes += len(payload)
            flush(ser)

        print(f"Upload complete, {total_bytes} bytes sent.")
        print("Waiting for core to jump to RAM...")
        wait_for_string(ser, "JMP", args.timeout)

        print("Program output:")
        print("-" * 40)
        stream_output(ser, args.prg_timeout)
        print("\n" + "-" * 40)


def load_firmware(hex_path):
    payloads = []
    with hex_path.open("r", encoding="utf-8") as f:
        for line_no, raw_line in enumerate(f, start=1):
            line = raw_line.strip()
            if not line:
                continue

            if len(line) % 2 != 0:
                raise ValueError(f"Invalid hex line length at line {line_no}: '{line}'")

            try:
                raw = bytes.fromhex(line)
                payloads.append(raw[::-1])
            except ValueError as e:
                raise ValueError(f"Invalid hex line at line {line_no}: '{line}'") from e

    if not payloads:
        raise ValueError("Input HEX file is empty")

    return payloads


def wait_for_string(port, token, timeout):
    deadline = time.monotonic() + timeout
    binary_token = token.encode("ascii")
    buffer = bytearray()

    while time.monotonic() < deadline:
        chunk = port.read(1)
        if chunk:
            buffer.extend(chunk)
            if binary_token in buffer:
                return

    raise TimeoutError(f"Timeout waiting for token '{token}'")


def flush(port):
    while port.in_waiting > 0:
        port.read(port.in_waiting)


def stream_output(port, timeout):
    deadline = time.monotonic() + timeout
    while True:
        chunk = port.read(1)
        if chunk:
            sys.stdout.write(chunk.decode("utf-8", errors="replace"))
            sys.stdout.flush()
            
            # Drain the rest of the available bytes quickly
            if port.in_waiting > 0:
                extra = port.read(port.in_waiting)
                sys.stdout.write(extra.decode("utf-8", errors="replace"))
                sys.stdout.flush()
                
            deadline = time.monotonic() + timeout
        elif time.monotonic() >= deadline:
            break


if __name__ == "__main__":
    main()
