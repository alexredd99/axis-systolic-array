
// multiply adder with latency L

module mul #(
  parameter  WX=4, WK=8, L=1,
  localparam WY=WX+WK
)(
  input  logic clk, rstn, en,
  input  logic signed [WX-1:0] x,
  input  logic signed [WK-1:0] k,
  output logic signed [WY-1:0] y
);
  logic [WY-1:0] m;
  always_ff @(posedge clk)
    if (!rstn)    m <= '0;
    else if (en)  m <= $signed(x) * $signed(k);

  n_delay #(.N(L-1),.W(WY)) mac_delay (.c(clk),.e(en),.rng(rstn),.rnl(rstn),.i(m),.o(y),.d());
endmodule

module acc #(
  parameter  WX=4, WY=16, L=1
)(
  input  logic clk, rstn, en, first,
  input  logic signed [WX-1:0] x,
  output logic signed [WY-1:0] y
);
  logic [WY-1:0] a;
  always_ff @(posedge clk)
    if (!rstn)   a <= '0;
    else if (en) a <= x + (first ? '0 : a);

  n_delay #(.N(L-1),.W(WY)) mac_delay (.c(clk),.e(en),.rng(rstn),.rnl(rstn),.i(a),.o(y),.d());
endmodule