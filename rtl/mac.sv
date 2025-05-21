`include "n_delay.sv"
`timescale 1ns / 1ps
`define MAX(a, b) ((a>b) ? a : b)

// multiply adder with latency L
(* use_dsp = "yes" *)
module integer_multiplier #(
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


(* use_dsp = "yes" *)
module minifloat_multiplier #(
    parameter  int unsigned ExpWidthX   = 4,
    parameter  int unsigned ExpWidthK   = 4,
    parameter  int unsigned ManWidthX   = 3,
    parameter  int unsigned ManWidthK   = 3,
    parameter  int unsigned Latency     = 1,
    // Binary format widths
    localparam int unsigned WidthX      = 1 + ExpWidthX + ManWidthX,
    localparam int unsigned WidthK      = 1 + ExpWidthK + ManWidthK,
    localparam int unsigned ManWidthMax = `MAX(ManWidthX, ManWidthK),
    localparam int unsigned ExpWidthMax = `MAX(ExpWidthX, ExpWidthK),
    // Fixed point product width
    localparam int unsigned WidthY      = 2 * (ManWidthMax + (2 ** ExpWidthMax))
) (
    input  logic                     clk_i,
    input  logic                     rst_ni,
    input  logic                     en_i,
    input  logic        [WidthX-1:0] x_i,
    input  logic        [WidthK-1:0] k_i,
    output logic signed [WidthY-1:0] y_o
);
  logic sign_x, sign_k;
  logic [ExpWidthX-1:0] exp_x;
  logic [ExpWidthK-1:0] exp_k;
  logic [ManWidthX-1:0] man_x;
  logic [ManWidthK-1:0] man_k;

  logic norm_x, norm_k;
  logic [(ManWidthX+1)-1:0] ext_man_x;  // + 1 for implicit bit
  logic [(ManWidthK+1)-1:0] ext_man_k;  // + 1 for implicit bit
  logic signed [(ManWidthX-1)+2:0] signed_man_x;  // +1 for implicit, +1 for sign
  logic signed [(ManWidthK-1)+2:0] signed_man_k;  // +1 for implicit, +1 for sign

  logic signed [WidthY-1:0] fixed_product;
  always_comb begin
    {sign_x, exp_x, man_x} = x_i;
    {sign_k, exp_k, man_k} = k_i;
    {norm_x, norm_k} = {|exp_x, |exp_k};

    ext_man_x = {norm_x, man_x};  // Extended mantissa w/ implicit bit
    ext_man_k = {norm_k, man_k};  // Extended mantissa w/ implicit bit
    signed_man_x = sign_x ? -ext_man_x : ext_man_x;  // Negative if sign == 1
    signed_man_k = sign_k ? -ext_man_k : ext_man_k;  // Negative if sign == 1

    fixed_product = ($signed(signed_man_x) * $signed(signed_man_k)) <<
        ($unsigned({1'b0, exp_x} + {1'b0, exp_k}) - $unsigned(norm_x) - $unsigned(norm_k));
  end

  logic signed [WidthY-1:0] temp_mul;
  always_ff @(posedge clk_i) begin
    if (!rst_ni) temp_mul <= '0;
    else if (en_i) temp_mul <= fixed_product;
  end

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
