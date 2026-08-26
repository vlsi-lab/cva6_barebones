// Copyright 2026 Federico Runco (federico.runco@gmail.com)
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// 
// Licensed under the Solderpad Hardware License v2.1 (the “License”); 
// you may not use this file except in compliance with the License, or, 
// at your option, the Apache License version 2.0. You may obtain a copy 
// of the License at https://solderpad.org/licenses/SHL-2.1/
// 
// Unless required by applicable law or agreed to in writing, any work 
// distributed under the License is distributed on an “AS IS” BASIS, WITHOUT 
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
// License for the specific language governing permissions and limitations 
// under the License.

package uart_pkg;

	typedef enum logic[3:0] {
		IDLE 		= 4'b0000,
		WAIT_TICK	= 4'b0011,
		START_BIT 	= 4'b0001,
		B0 			= 4'b1000,
		B1 			= 4'b1001,
		B2 			= 4'b1010,
		B3 			= 4'b1011,
		B4	 		= 4'b1100,
		B5 			= 4'b1101,
		B6 			= 4'b1110,
		B7 			= 4'b1111,
		STOP_BIT 	= 4'b0010
	} uart_state_t;

endpackage