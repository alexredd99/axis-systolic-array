`include "n_delay.sv"
`timescale 1ns / 1ps

// multiply adder with latency L
(* use_dsp = "yes" *)
module mul #(
    parameter  int unsigned WidthX  = 4,
    parameter  int unsigned WidthK  = 8,
    parameter  int unsigned Latency = 1,
    localparam int unsigned WidthY  = WidthX + WidthK
) (
    input  logic                     clk_i,
    input  logic                     rst_ni,
    input  logic                     en_i,
    input  logic signed [WidthX-1:0] x_i,
    input  logic signed [WidthK-1:0] k_i,
    output logic signed [WidthY-1:0] y_o
);
  logic signed [WidthY-1:0] temp_mul;
  always_ff @(posedge clk_i)
    if (!rst_ni) temp_mul <= '0;
    else if (en_i) temp_mul <= $signed(x_i) * $signed(k_i);

  n_delay #(
      .Latency(Latency - 1),
      .Width  (WidthY)
  ) i_mac_delay (
      .clk_i   (clk_i),
      .en_i    (en_i),
      .rst_ni  (rst_ni),
      .data_i  (temp_mul),
      .data_o  (y_o),
      .buffer_o()
  );
endmodule

module acc #(
    parameter int unsigned WidthX  = 4,
    parameter int unsigned WidthY  = 16,
    parameter int unsigned Latency = 1
) (
    input  logic                     clk_i,
    input  logic                     rst_ni,
    input  logic                     en_i,
    input  logic                     x_valid_i,
    input  logic                     first_i,
    input  logic signed [WidthX-1:0] x_i,
    output logic signed [WidthY-1:0] y_o
);
  logic signed [WidthY-1:0] temp_acc;
  // only accumulate valid data
  always_ff @(posedge clk_i)
    if (!rst_ni) temp_acc <= '0;
    else if (en_i && x_valid_i) begin
      temp_acc <= WidthY'($signed(x_i)) + $signed(first_i ? WidthY'(0) : temp_acc);
    end

  n_delay #(
      .Latency(Latency - 1),
      .Width  (WidthY)
  ) i_mac_delay (
      .clk_i   (clk_i),
      .en_i    (en_i),
      .rst_ni  (rst_ni),
      .data_i  (temp_acc),
      .data_o  (y_o),
      .buffer_o()
  );
endmodule
