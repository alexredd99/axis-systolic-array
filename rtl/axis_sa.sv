`timescale 1ns/1ps
`define DIAG(a, b) (a+b)

// AXI Stream Systolic Array

module axis_sa #(
    parameter  R=4, C=8, WX=4, WK=8, WY=16, LM=1, LA=1
  )(
    input  logic clk, rstn,
    input  logic s_valid, s_last, m_ready,
    output logic s_ready, m_valid, m_last, 
    input  logic [R-1:0][WX-1:0] sx_data,
    input  logic [C-1:0][WK-1:0] sk_data,
    output logic [R-1:0][WY-1:0] m_data
  );

  genvar r, c, d ;
  localparam D  = `DIAG(R,C)-1; // length of diagonal
  localparam WM = WX + WK;

  logic en_mac, en_shift, first_xk_00;

  logic [R-1:0][WX-1:0] xi_delayed;
  logic [C-1:0][WK-1:0] ki_delayed, sk_reversed;

  logic [R-1:0][C-1:0][WX-1:0] xi;
  logic [R-1:0][C-1:0][WK-1:0] ki;
  logic [R-1:0][C-1:0][WM-1:0] mo;
  logic [R-1:0][C-1:0][WY-1:0] ao, ro;

  logic [D-1:0] en_acc, r_valid, r_last, reg_copy, reg_clear, conflict, ad_valid;
  logic [LM+D-1:0] first;
  logic [LM+LA+D-1:0] valid, valid_last;

  // Global Control
  assign en_mac   = !(|conflict); // pull en_mac down if any acc is pushing data (avalid) and reg already has data (r_valid)
  assign en_shift = r_valid[D-1] && m_ready;  // shift only when entire array is full (m_valid) and mready
  assign s_ready  = en_mac;

  // Reverse the columns of K matrix, so that outputs come out with C=0 first
  for (c=0; c<C; c=c+1)
    assign sk_reversed[c] = sk_data[C-1-c];

  // Triangular Buffer for x and k
  tri_buffer #(.W(WX), .N(R)) TRI_X (.clk(clk), .rstn(rstn), .cen(en_mac), .x(sx_data    ), .y(xi_delayed));
  tri_buffer #(.W(WK), .N(C)) TRI_K (.clk(clk), .rstn(rstn), .cen(en_mac), .x(sk_reversed), .y(ki_delayed));

  // Delay control signals
  n_delay #(.N(LM   +D), .W(1)) FIRST      (.c(clk), .e(en_mac), .rng(rstn), .rnl(rstn), .i(first_xk_00       ), .o(), .d(first));
  n_delay #(.N(LM+LA+D), .W(1)) VALID      (.c(clk), .e(en_mac), .rng(rstn), .rnl(rstn), .i(s_valid           ), .o(), .d(valid));
  n_delay #(.N(LM+LA+D), .W(1)) VALID_LAST (.c(clk), .e(en_mac), .rng(rstn), .rnl(rstn), .i(s_valid && s_last ), .o(), .d(valid_last));

  // Propagate x and k through the array
  for (r=0; r<R; r=r+1)
    for (c=0; c<C; c=c+1) begin

      if (c==0) 
        assign xi[r][c] = xi_delayed[r];  
      else // move x through cols
        always_ff @(posedge clk)
          if (!rstn)       xi[r][c] <= '0;
          else if (en_mac) xi[r][c] <= xi[r][c-1];
      
      if (r==0)
        assign ki[r][c] = ki_delayed[c];
      else // move k through rows
        always_ff @(posedge clk)
          if (!rstn)       ki[r][c] <= '0;
          else if (en_mac) ki[r][c] <= ki[r-1][c];
    end

  // Multipliers
  for (r=0; r<R; r=r+1) begin: MR
    for (c=0; c<C; c=c+1) begin: MC    
      mul #(.WX(WX), .WK(WK), .L(LM)) MUL (.clk(clk), .rstn(rstn), .en(en_mac),.x(xi[r][c]),.k(ki[r][c]),.y(mo[r][c]));
  end end

  // Accumulators - cleared at first beat of s_axis packet
  always_ff @(posedge clk)
    if (!rstn)                  first_xk_00 <= 1'b1;
    else if (en_mac && s_valid) first_xk_00 <= s_last;

  for (r=0; r<R; r=r+1) begin: AR
    for (c=0; c<C; c=c+1) begin: AC
    // only accumulate valid data
      localparam d = `DIAG(r,c);
      assign en_acc[d] = en_mac && valid[LM+d]; 
      acc #(.WX(WM),.WY(WY),.L(LA)) ACC (.clk(clk), .rstn(rstn), .en(en_acc[d]), .first (first[LM+d]), .x(mo[r][c]), .y(ao[r][c]));
  end end


  // Output Register Control

  assign r_last[0] = r_valid[0];

  for (d=1; d<D; d=d+1)
    always_ff @(posedge clk)
      if (!rstn)                r_last[d] <= 0;
      else if (en_shift) 
        if (d >= C-1 && m_last) r_last[d] <= 0;            // At the last beat, clear all diagonal regs beyond C
        else                    r_last[d] <= r_last[d-1];  // on non-last beats, shift right
  
  for (d=0; d<D; d=d+1)
    always_ff @(posedge clk)
      if (!rstn)                         ad_valid[d] <= 0;
      else if (conflict [d] && en_shift) ad_valid[d] <= 0;
      else if (en_mac)                   ad_valid[d] <= valid_last[LM+LA+d-1];

  for (d=0; d<D; d=d+1)
    always_comb begin
      conflict [d] = r_valid [d] && ad_valid[d]; // acc wants to send data, but reg already has data
      reg_copy [d] = ad_valid[d] && !r_valid[d]; // copy only if acc can send data (ad_valid) and reg is empty (!r_valid)
      reg_clear[d] = en_shift    &&  r_last [d]; // clear if current reg is last
    end

  for (d=0; d<D; d=d+1)
    always_ff @(posedge clk)
      if (!rstn)                               r_valid[d] <= 0;
      else if (d >= C-1 && en_shift && m_last) r_valid[d] <= 0; // At the last beat, clear all diagonal regs beyond C
      else if (reg_copy [d])                   r_valid[d] <= 1;
      else if (reg_clear[d])                   r_valid[d] <= 0;

  // Output Register Data
  for (r=0; r<R; r=r+1) begin
    // c=0
    always_ff @(posedge clk)
      if (!rstn)                       ro[r][0] <= '0;
      else if (reg_copy[`DIAG(r,0)])   ro[r][0] <= ao[r][0];
    // c!=0
    for (c=1; c<C; c=c+1)
      always_ff @(posedge clk)
        if (!rstn)                     ro[r][c] <= '0;
        else if (reg_copy[`DIAG(r,c)]) ro[r][c] <= ao[r][c];
        else if (en_shift)             ro[r][c] <= ro[r][c-1];
  end

  // Outputs
  assign m_valid = r_valid[D-1];
  assign m_last  = r_last [C-1];

  for (r=0; r<R; r=r+1)
    assign m_data[r] = ro[r][C-1];
  
endmodule