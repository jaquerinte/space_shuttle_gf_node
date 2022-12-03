// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter integer WORD_SIZE = 32,
    parameter integer REGISTERS = 32,
    parameter integer REGDIRSIZE = 4,
    parameter integer ECCBITS = 7,
    parameter integer VERIFICATION_PINS = 2,
    parameter integer WHISBONE_ADR = 32,
    parameter integer COUNTERSIZE = 32
)(
`ifdef USE_POWER_PINS
    inout vdd,	// User area 1 1.8V supply
    inout vss,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [63:0] la_data_in,
    output [63:0] la_data_out,
    input  [63:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    wire clk;
    wire rst;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;

    wire [WORD_SIZE-1:0] rdata; 
    wire [WORD_SIZE-1:0] wdata;
    wire [WORD_SIZE-1:0] output_data;
    wire operational;
    wire [VERIFICATION_PINS-1:0] output_verification;

    wire valid;
    wire [3:0] wstrb;
    wire [31:0] la_write;

    // WB MI A
    assign valid = wbs_cyc_i && wbs_stb_i; 
    assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wbs_dat_o = rdata;
    assign wdata = wbs_dat_i;

    // IO
    assign io_out = {output_verification,output_data[15:0],operational, 19'b0};//{6'b000000,output_data};b
    assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};

    // IRQ
    assign irq = 3'b000;	// Unused

    // LA
    assign la_data_out = {{(64-WORD_SIZE+VERIFICATION_PINS+1){1'b0}}, output_data, output_verification,operational};
    // Assuming LA probes [63:32] are for controlling the count register  
    
    assign clk = (~la_oenb[31]) ? (~la_oenb[30] ? la_data_in[29] : user_clk ) : wb_clk_i;
    //assign clk = (~la_oenb[29]) ? la_data_in[29]: wb_clk_i;
    assign rst = (~la_oenb[30]) ? la_data_in[30]: wb_rst_i;

    register_file #(
        .WORD_SIZE (WORD_SIZE),
        .REGISTERS (REGISTERS),
        .WHISBONE_ADR (WHISBONE_ADR),
        .VERIFICATION_PINS (VERIFICATION_PINS),
        .REGDIRSIZE (REGDIRSIZE),
        .ECCBITS (ECCBITS),
        .COUNTERSIZE (COUNTERSIZE)
    ) register_file(
        `ifdef USE_POWER_PINS
        .vdda1(vdda1),	// User area 1 3.3V power
        .vdda2(vdda2),	// User area 2 3.3V power
        .vssa1(vssa1),	// User area 1 analog ground
        .vssa2(vssa2),	// User area 2 analog ground
        .vccd1(vccd1),	// User area 1 1.8V power
        .vccd2(vccd2),	// User area 2 1.8V power
        .vssd1(vssd1),	// User area 1 digital ground
        .vssd2(vssd2),	// User area 2 digital ground
        `endif
        .clk_i(clk),
        .rst_i(rst),
        .valid_i(valid),
        .wstrb_i(wstrb),
        .wdata_i(wdata),
        .wbs_we_i(wbs_we_i),
        .operation_type_i (la_data_in[4:2]),
        .data_to_register_i(la_data_in[63:32]),
        .register_i(la_data_in[9:5]),
        .wregister_i(la_data_in[1]),
        .rregister_i(la_data_in[0]),
        .wbs_adr_i (wbs_adr_i),
        .store_data_o(output_data),
        .operational_o(operational),
        .operation_result_o(output_verification),
        .ready_o(wbs_ack_o),
        .rdata_o(rdata)
    );

endmodule

`default_nettype wire
