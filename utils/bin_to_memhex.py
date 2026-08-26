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
from pathlib import Path


def main():
	parser = argparse.ArgumentParser(description="Binary to SRAM hex file converter")
	parser.add_argument("--input", required=True, help="Input binary file")
	parser.add_argument("--output", required=True, help="Output hex file")
	parser.add_argument("--word-bytes", type=int, default=8, help="Word size in bytes (default: 8)")
	parser.add_argument("--header", action="store_true", help="Add BootROM specific header")
	args = parser.parse_args()

	in_path = Path(args.input)
	out_path = Path(args.output)
	word_bytes = args.word_bytes

	if word_bytes <= 0:
		raise ValueError("--word-bytes must be > 0")

	data = in_path.read_bytes()
	pad = (-len(data)) % word_bytes
	if pad:
		data += b"\x00" * pad

	with out_path.open("w", encoding="utf-8") as f:
		if args.header:
			num_lines = len(data)
			f.write(f"{num_lines:08x}b007babe\n")

		for idx in range(0, len(data), word_bytes):
			chunk = data[idx:idx + word_bytes]
			value = int.from_bytes(chunk, byteorder="little", signed=False)
			f.write(f"{value:0{word_bytes * 2}x}\n")


if __name__ == "__main__":
	main()