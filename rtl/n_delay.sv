`timescale 1ns/1ps

module n_delay #(
  parameter N = 1,
            W = 8
)(
  input  logic c, e, rng, rnl,
  input  logic        [W-1:0] i,
  output logic        [W-1:0] o,
  output logic [N-1:0][W-1:0] d
);
  logic [(N+1)-1:0][W-1:0]  data;

  always_comb data [0] = i;
  assign o = data[(N+1)-1];

  genvar n;
  generate 
  for (n=0 ; n < N; n++) begin : n_dat
    always_ff @(posedge c or negedge rng)
      if (!rng)      data [n+1] <= 0;
      else if (!rnl) data [n+1] <= 0;
      else if (e)    data [n+1] <= data [n];
  end
  endgenerate

  if (N > 1) assign d = data[N:1];
  else       assign d = data[0];

endmodule