`include "../rtl/axis_sa.sv"

module integer_axis_sa_tb;
  parameter Rows = 2;
  parameter Cols = 4;
  localparam K = 8;
  parameter WidthX = 4;
  parameter WidthK = 4;
  parameter WidthY = 16;

  bit signed [WidthX-1:0] data_x[0:(Rows-1)][0:(K-1)];
  bit signed [WidthK-1:0] data_k[0:(Cols-1)][0:(K-1)];
  // bit signed [WidthY-1:0] golden[0:(Cols-1)][0:(Rows-1)];

  logic signed [WidthY-1:0] actual[0:(Rows-1)][0:(Cols-1)];

  logic clk_i = 0, rst_ni = 0;
  initial forever #5 clk_i = ~clk_i;

  logic s_valid_i = 0, s_last_i = 0, m_ready_i = 0;
  logic s_ready_o, m_valid_o, m_last_o;
  logic [Rows-1:0][WidthX-1:0] sx_data_i;
  logic [Cols-1:0][WidthK-1:0] sk_data_i;
  logic [Rows-1:0][WidthY-1:0] m_data_o;

  axis_sa #(
      .Rows  (Rows),
      .Cols  (Cols),
      .WidthX(WidthX),
      .WidthK(WidthK),
      .WidthY(WidthY)
  ) dut (
      .*
  );

  initial begin
    $readmemh("data_x.txt", data_x);
    $readmemh("data_k.txt", data_k);
    // $readmemh("golden.txt", golden);

    $dumpfile("dump.vcd");
    $dumpvars;

    @(posedge clk_i);
    rst_ni <= 1;
    repeat (2) @(posedge clk_i);

    for (int k = 0; k < K; k++) begin
      #1;
      s_valid_i = 1;
      s_last_i  = (k == K - 1) ? 1 : 0;

      for (int r = 0; r < Rows; r++) sx_data_i[r] = data_x[r][k];
      for (int c = 0; c < Cols; c++) sk_data_i[c] = data_k[c][k];

      @(posedge clk_i);
    end
    #1;
    s_valid_i = 0;
    s_last_i  = 0;
    m_ready_i = 1;

    // Wait until data ready
    while (!m_valid_o) @(posedge clk_i);

    for (int c = 0; c < Cols; c++) begin
      for (int r = 0; r < Rows; r++) begin
        $display("row: %d, col: %d", r, c);
        actual[r][c] = m_data_o[r];
      end
      @(posedge clk_i);
    end

    repeat (10) @(posedge clk_i);

    for (int r = 0; r < Rows; r++) begin
      for (int c = 0; c < Cols; c++) begin
        $write("%d ", actual[r][c]);
      end
      $display();
    end

    $finish();
  end
endmodule
