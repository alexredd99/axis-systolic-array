`timescale 1ns/1ps

module axis_sa_tb;
  localparam 
    R          = 2, 
    C          = 2, 
    K          = 2,
    WX         = 4, 
    WK         = 4,
    LM         = 1,
    LA         = 1,
    WY         = WX + WK + $clog2(K),
    WXK_BUS    = WX*R + WK*C,
    WY_BUS     = WY*R,
    P_VALID    = 100, 
    P_READY    = 100,
    CLK_PERIOD = 10, 
    NUM_EXP    = 2;

  logic clk=0, rstn=0;
  initial forever #(CLK_PERIOD/2) clk = ~clk;

  int file_in, file_out, file_exp, status;
  string path_in, path_out, path_exp;

  // Systolic Array

  logic s_ready, s_valid, s_last, m_ready, m_valid, m_last;
  logic [R-1:0][WX-1:0] sx_data;
  logic [C-1:0][WK-1:0] sk_data;
  logic [R-1:0][WY-1:0] m_data;

  axis_sa #(.R(R), .C(C), .WX(WX), .WK(WK), .WY(WY), .LM(LM), .LA(LA)) DUT (.*);

  // AXI Stream Source and Sink

  logic [WXK_BUS  -1:0] s_data;
  logic [WXK_BUS/2-1:0] s_keep;
  logic [R-1        :0] m_keep = '1;

  AXIS_Source #(.WORD_WIDTH(2 ), .BUS_WIDTH(WXK_BUS), .PROB_VALID(P_VALID)) source (.aclk(clk), .aresetn(rstn), .*);
  AXIS_Sink   #(.WORD_WIDTH(WY), .BUS_WIDTH(WY_BUS ), .PROB_READY(P_READY)) sink   (.aclk(clk), .aresetn(rstn), .*);
  assign {sk_data, sx_data} = s_data;

  // Matrices
  // X(R,K) * K(K,C) = Y(R,C)
  logic signed [NUM_EXP-1:0][R-1:0][K-1:0][WX-1:0] xm; // (R,K)
  logic signed [NUM_EXP-1:0][K-1:0][C-1:0][WK-1:0] km; // (K,C)
  logic signed [NUM_EXP-1:0][R-1:0][C-1:0][WY-1:0] ym; // (R,C)

  logic [R-1:0][WX-1:0] x_row;
  logic [C-1:0][WK-1:0] k_col;
  logic [WXK_BUS/2-1:0][1:0] xk2;
  logic [WY-1:0] y_val;

  
  initial 
    for (int n=0; n<NUM_EXP; n++) begin

      path_in  = $sformatf("inp_%0d.txt",n);
      file_in  = $fopen(path_in , "w");

      path_exp = $sformatf("exp_%0d.txt",n);
      file_exp = $fopen(path_exp, "w");

      // Randomize x
      xm[n][0][0] = -1;
      xm[n][0][1] =  2;
      xm[n][1][0] =  3;
      xm[n][1][1] = -1; 
      $display("%0d) xm:", n);
      for (int r=0; r<R; r++) begin
        $write("| ");
        for (int k=0; k<K; k++) begin
          // xm[n][r][k] = WX'($urandom_range(0,2**WX-1));
          $write("%d ",  $signed(xm[n][r][k]));
        end 
        $write("|\n");
      end

      // Randomize k
      km[n][0][0] = 7;
      km[n][0][1] = 6;
      km[n][1][0] =-4;
      km[n][1][1] = 6; 
      $display("%0d) km:", n);
      for (int k=0; k<K; k++) begin
        $write("| ");
        for (int c=0; c<R; c++) begin
          // km[n][k][c] = WK'($urandom_range(0,2**WK-1));
          $write("%d ",  $signed(km[n][k][c]));
        end
        $write("|\n");
      end

      // Concat and write to file
      for (int k=0; k<K; k++) begin

        for (int r=0; r<R; r++)
          x_row[r] = xm[n][r][k];
        for (int c=0; c<C; c++)
          k_col[c] = km[n][k][c];

        xk2 = {k_col, x_row};

        for (int i=0; i<WXK_BUS/2; i++)
          $fdisplay(file_in, "%d", xk2[i]);
      end

      // Expected y
      ym = 0;
      for (int r=0; r<R; r++)
        for (int c=0; c<C; c++)
          for (int k=0; k<K; k++)
            ym[n][r][c] = $signed(ym[n][r][c]) + $signed(xm[n][r][k]) * $signed(km[n][k][c]);
      
      $display("%0d) ym:", n);
      for (int r=0; r<R; r++) begin
        $write("| ");
        for (int c=0; c<C; c++)
          $write("%d ",  $signed(ym[n][r][c]));
        $write("|\n");
      end


      for (int c=C-1; c>=0; c--) // last column comes out first
        for (int r=0; r<R; r++)
          $fdisplay(file_exp, "%d",  $signed(ym[n][r][c]));
      
      $fclose(file_in);
      $fclose(file_exp);

      source.axis_push (path_in);
      @(posedge clk);
    end

  initial begin
    $dumpfile ("axis_tb.vcd"); $dumpvars;

    rstn = 0;
    repeat(2) @(posedge clk);
    rstn = 1;

    for (int n=0; n<NUM_EXP; n++) begin
    
      path_out = $sformatf("out_%0d.txt",n);
      sink.axis_pull (path_out);
      $display("Done axis pull");

      file_out = $fopen(path_out, "r");
      for (int r=0; r<R; r++)
        for (int c=C-1; c<=0; c--) begin
          status = $fscanf(file_out,"%d\n", y_val);
          assert (y_val == ym[n][r][c]) else $error("Output does not match");
        end
      $fclose(file_out);
    end
    $finish();
  end

endmodule 