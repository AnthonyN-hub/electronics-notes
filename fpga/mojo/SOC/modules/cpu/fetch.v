/*
 * Instruction fetch module.
 *
 * This implements a master wishbone controller to query the memory for an
 * instruction.
 *
 * TODO: add stall signal
 *
 * This controller has four states:
 *
 *  IDLE: it's not active, has strobe and cycle not asserted waiting for
 *  enable to be asserted
 *  START TRANSACTION: enable is asserted, cycle and strobe are asserted
 *  WAITING RESULT: strobe deasserted, waiting for acknowledge
 *  COMPLETED: cycle deasserted and completed asserted
 *
 *  Some hints adopted from
 *   <https://zipcpu.com/zipcpu/2017/11/18/wb-prefetch.html>.
 *
 * FIXME: this module is a smoking shit, I should rework it! the use of a flag
 * to remember it has been selected it's not a smart move. Also the o_wb_we
 * signal should be a simple wire but the simulator seems to behaves strangely
 * using it.
 */
`timescale 1ns/1ps
`default_nettype none

module fetch(
    input wire clk,
    input wire reset,
    input wire i_enable, /* from cpu */
    input wire [31:0] i_pc, /* from cpu */
    output reg [31:0] o_instruction, /* to cpu */
    input wire [31:0] i_value,
    output reg o_completed, /* to cpu */
    output reg o_wb_cyc,
    output reg o_wb_stb,
    output reg o_wb_we,
    input wire [31:0] i_wb_data, /* from here is coming the data from the memory */
    output reg [31:0] o_wb_data, /* from here is going the data to memory */
    input wire i_wb_ack,
    input wire i_we,
    output reg [31:0] o_wb_addr, /* this is the requested address */
    input wire [1:0] i_data_width, /* this indicates if access happens in byte/short/word */
    output wire [1:0] o_data_width /* this indicates if access happens in byte/short/word */
);

initial begin
    o_wb_cyc = 1'b0;
    o_wb_stb = 1'b0;
end

/* this signal is used to REMEMBER WE HAVE BEEN SELECTED */
reg selected;

always @(posedge clk)
/* IDLE: from a reset or from an ack during a transaction */
if (~reset | (i_wb_ack && o_wb_cyc && selected))
begin
    if (~reset)
        selected <= 1'b0;
    o_wb_cyc <= 1'b0;
    o_wb_stb <= 1'b0;
end
/* START TRANSACTION: it's enabled so we assert cycle and strobe */
else if (!o_wb_cyc && i_enable)
begin
    selected <= 1'b1;
    o_wb_cyc <= 1'b1;
    o_wb_stb <= 1'b1;
    o_wb_addr <= i_pc;

    if (i_we) begin
        o_wb_we <= i_we;
        o_wb_data <= i_value;
    end
end
/* WAITING RESULT */
else if(o_wb_cyc && selected)
begin
    o_wb_stb <= 1'b0;
end

/* COMPLETED */
always @(posedge clk) begin
    if (o_wb_cyc && i_wb_ack && selected) begin
        o_instruction <= i_wb_data;
        o_completed <= 1'b1;
    end
    else if (o_completed && selected) begin
        o_completed <= 1'b0;
        selected <= 1'b0;
        o_wb_we <= 1'b0;
    end
end

assign o_data_width = i_data_width;

endmodule
