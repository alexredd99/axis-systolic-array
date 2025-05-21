`include "mac.sv"
`include "tri_buffer.sv"
`timescale 1ns / 1ps
`define DIAG(a, b) (a+b)

typedef enum int {
  MAC_INT = 0,
  MAC_FP  = 1
} mac_type_e;

module axis_sa #(
    // Generic params
    parameter int unsigned LatencyMul = 1,
    parameter int unsigned LatencyAcc = 1,
    parameter int unsigned Rows = 4,
    parameter int unsigned Cols = 8,
    parameter int unsigned WidthY = 16,  // Accumulator Width
    parameter mac_type_e MacType = MAC_INT,
    // Integer MAC params
    parameter int unsigned WidthX = 4,
    parameter int unsigned WidthK = 8,
    // Minifloat MAC params
    parameter int unsigned ExpWidthX = 4,
    parameter int unsigned ExpWidthK = 4,
    parameter int unsigned ManWidthX = 3,
    parameter int unsigned ManWidthK = 3,
    // Derived integer MAC params
    parameter int unsigned WidthM = WidthX + WidthK,  // MAC out
    // Derived minifloat MAC params
    localparam int unsigned FpWidthX = 1 + ExpWidthX + ManWidthX,
    localparam int unsigned FpWidthK = 1 + ExpWidthK + ManWidthK,
    localparam int unsigned ManWidthMax = `MAX(ManWidthX, ManWidthK),
    localparam int unsigned ExpWidthMax = `MAX(ExpWidthX, ExpWidthK),
    localparam int unsigned FpWidthM = 2 * (ManWidthMax + (2 ** ExpWidthMax)),
    // Generic derived params
    localparam int unsigned DiagLen = `DIAG(Rows, Cols) - 1,
    localparam int unsigned ActualWidthX = (MacType == MAC_INT) ? WidthX : FpWidthX,
    localparam int unsigned ActualWidthK = (MacType == MAC_INT) ? WidthK : FpWidthK,
    localparam int unsigned ActualWidthM = (MacType == MAC_INT) ? WidthY : FpWidthM
) (
    input  logic                              clk_i,
    input  logic                              rst_ni,
    input  logic                              s_valid_i,
    input  logic                              s_last_i,
    input  logic                              m_ready_i,
    output logic                              s_ready_o,
    output logic                              m_valid_o,
    output logic                              m_last_o,
    input  logic [Rows-1:0][ActualWidthX-1:0] sx_data_i,
    input  logic [Cols-1:0][ActualWidthK-1:0] sk_data_i,
    output logic [Rows-1:0][      WidthY-1:0] m_data_o
);
  logic en_mac, en_shift;

  logic [Rows-1:0][ActualWidthX-1:0] xi_delayed;
  logic [Cols-1:0][ActualWidthK-1:0] ki_delayed, sk_reversed;
  logic [Rows-1:0][Cols-1:0][ActualWidthX-1:0] xi;
  logic [Rows-1:0][Cols-1:0][ActualWidthK-1:0] ki;
  logic [Rows-1:0][Cols-1:0][ActualWidthM-1:0] mo;
  logic [Rows-1:0][Cols-1:0][WidthY-1:0] ao, ro;

  // Control Signals are passed diagonally through the array
  logic [DiagLen-1:0] r_valid, r_last, r_copy, r_clear, conflict, a_valid, m_first;
  logic [LatencyMul+LatencyAcc+DiagLen-1:0] valid, vlast;

  // Global Control
  assign en_mac   = !(|conflict); // pull en_mac down if any acc is pushing data (avalid) and reg already has data (r_valid)
  assign en_shift = r_valid[DiagLen-1] && m_ready_i;  // shift only when entire array is full (m_valid_o) and mready
  assign s_ready_o = en_mac;

  // Reverse the columns of K matrix, so that outputs come out with Cols=0 first
  for (genvar c = 0; c < Cols; c++) assign sk_reversed[c] = sk_data_i[Cols-1-c];

  // Triangular Buffer for x and k
  tri_buffer #(
      .Width(ActualWidthX),
      .Size (Rows)
  ) i_tri_x (
      .clk_i (clk_i),
      .rst_ni(rst_ni),
      .en_i  (en_mac),
      .x_i   (sx_data_i),
      .y_o   (xi_delayed)
  );

  tri_buffer #(
      .Width(ActualWidthK),
      .Size (Cols)
  ) i_tri_k (
      .clk_i (clk_i),
      .rst_ni(rst_ni),
      .en_i  (en_mac),
      .x_i   (sk_reversed),
      .y_o   (ki_delayed)
  );

  // Delay control signals
  n_delay #(
      .Latency(LatencyMul + LatencyAcc + DiagLen),
      .Width  (1)
  ) i_valid (
      .clk_i   (clk_i),
      .en_i    (en_mac),
      .rst_ni  (rst_ni),
      .data_i  (s_valid_i),
      .data_o  (),
      .buffer_o(valid)
  );

  n_delay #(
      .Latency(LatencyMul + LatencyAcc + DiagLen),
      .Width  (1)
  ) i_vlast (
      .clk_i   (clk_i),
      .en_i    (en_mac),
      .rst_ni  (rst_ni),
      .data_i  (s_valid_i && s_last_i),
      .data_o  (),
      .buffer_o(vlast)
  );

  // Propagate x and k through the array
  for (genvar r = 0; r < Rows; r++) begin
    for (genvar c = 0; c < Cols; c++) begin
      if (c == 0) assign xi[r][c] = xi_delayed[r];
      else  // move x through cols
        always_ff @(posedge clk_i)
          if (!rst_ni) xi[r][c] <= '0;
          else if (en_mac) xi[r][c] <= xi[r][c-1];

      if (r == 0) assign ki[r][c] = ki_delayed[c];
      else  // move k through rows
        always_ff @(posedge clk_i)
          if (!rst_ni) ki[r][c] <= '0;
          else if (en_mac) ki[r][c] <= ki[r-1][c];
    end
  end

  // Multipliers
  for (genvar r = 0; r < Rows; r++) begin : MR
    for (genvar c = 0; c < Cols; c++) begin : MC
      if (MacType == MAC_INT) begin
        integer_multiplier #(
            .WidthX (WidthX),
            .WidthK (WidthK),
            .Latency(LatencyMul)
        ) MUL (
            .clk_i (clk_i),
            .rst_ni(rst_ni),
            .en_i  (en_mac),
            .x_i   (xi[r][c]),
            .k_i   (ki[r][c]),
            .y_o   (mo[r][c])
        );
      end else begin
        minifloat_multiplier #(
            .ExpWidthX(ExpWidthX),
            .ExpWidthK(ExpWidthK),
            .ManWidthX(ManWidthX),
            .ManWidthK(ManWidthK),
            .Latency  (LatencyMul)
        ) MUL (
            .clk_i (clk_i),
            .rst_ni(rst_ni),
            .en_i  (en_mac),
            .x_i   (xi[r][c]),
            .k_i   (ki[r][c]),
            .y_o   (mo[r][c])
        );
      end
    end
  end

  // Accumulators
  for (genvar d = 0; d < DiagLen; d++) begin
    always_ff @(posedge clk_i)
      if (!rst_ni) m_first[d] <= 1'b1;
      else if (valid[LatencyMul+d]) m_first[d] <= vlast[LatencyMul+d];
  end

  for (genvar r = 0; r < Rows; r++) begin : AR
    for (genvar c = 0; c < Cols; c++) begin : AC
      localparam d = `DIAG(r, c);
      acc #(
          .WidthX (ActualWidthM),
          .WidthY (WidthY),
          .Latency(LatencyAcc)
      ) ACC (
          .clk_i    (clk_i),
          .rst_ni   (rst_ni),
          .en_i     (en_mac),
          .x_valid_i(valid[LatencyMul+d]),
          .first_i  (m_first[d]),
          .x_i      (mo[r][c]),
          .y_o      (ao[r][c])
      );
    end
  end

  // Output Register Control
  for (genvar d = 0; d < DiagLen; d++) begin
    if (d == 0) assign r_last[0] = r_valid[0];
    else
      always_ff @(posedge clk_i)
        if (!rst_ni) r_last[d] <= 0;
        else if (en_shift)
          if ((d >= (Cols - 1)) && m_last_o)
            r_last[d] <= 0;  // At the last beat, clear all diagonal regs beyond Cols
          else r_last[d] <= r_last[d-1];  // on non-last beats, shift right

    always_ff @(posedge clk_i)
      if (!rst_ni) a_valid[d] <= 0;
      else if (en_mac) a_valid[d] <= vlast[LatencyMul+LatencyAcc+d-1];

    assign conflict [d] = a_valid[d]  &&  r_valid[d]; // acc wants to send data, but reg already has data
    assign r_copy   [d] = a_valid[d]  && !r_valid[d]; // copy only if acc can send data (a_valid) and reg is empty (!r_valid)
    assign r_clear[d] = en_shift && r_last[d];  // clear if current reg is last

    always_ff @(posedge clk_i)
      if (!rst_ni) r_valid[d] <= 0;
      else if ((d >= (Cols - 1)) && en_shift && m_last_o)
        r_valid[d] <= 0;  // At the last beat, clear all diagonal regs beyond Cols
      else if (r_copy[d]) r_valid[d] <= 1;
      else if (r_clear[d]) r_valid[d] <= 0;
  end

  // Output Register Data
  for (genvar r = 0; r < Rows; r++) begin
    for (genvar c = 0; c < Cols; c++) begin
      if (c == 0) begin
        always_ff @(posedge clk_i)
          if (!rst_ni) ro[r][0] <= '0;
          else if (r_copy[`DIAG(r, 0)]) ro[r][0] <= ao[r][0];
      end else begin
        always_ff @(posedge clk_i)
          if (!rst_ni) ro[r][c] <= '0;
          else if (r_copy[`DIAG(r, c)]) ro[r][c] <= ao[r][c];
          else if (en_shift) ro[r][c] <= ro[r][c-1];
      end
    end
  end

  // Outputs
  assign m_valid_o = r_valid[DiagLen-1];
  assign m_last_o  = r_last[Cols-1];

  for (genvar r = 0; r < Rows; r++) assign m_data_o[r] = ro[r][Cols-1];

endmodule
