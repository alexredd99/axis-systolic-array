`timescale 1ns/1ps
`define DIAG(a, b) (a+b)

module axis_sa_tb;
  localparam 
    R          = 2, 
    C          = 2, 
    K          = 6,
    WX         = 4, 
    WK         = 4,
    LM         = 1,
    LA         = 1,
    WM         = WX + WK,
    WY         = WM + $clog2(K),
    WXK_BUS    = WX*R + WK*C,
    WY_BUS     = WY*R,
    P_VALID    = 1, 
    P_READY    = 50,
    CLK_PERIOD = 10, 
    NUM_EXP    = 50;

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
  bit signed [NUM_EXP-1:0][R-1:0][K-1:0][WX-1:0] xm = '0; // (R,K)
  bit signed [NUM_EXP-1:0][K-1:0][C-1:0][WK-1:0] km = '0; // (K,C)
  bit signed [NUM_EXP-1:0][R-1:0][C-1:0][WY-1:0] ym = '0; // (R,C)

  bit signed [NUM_EXP-1:0][K-1:0][R-1:0][C-1:0][WM-1:0] mm = '0;
  bit signed [NUM_EXP-1:0][K-1:0][R-1:0][C-1:0][WY-1:0] am = '0;

  logic [R-1:0][WX-1:0] x_row;
  logic [C-1:0][WK-1:0] k_col;
  logic [WXK_BUS/2-1:0][1:0] xk2;
  logic signed [WY-1:0] y_val, y_exp;
  int ur = $urandom(500);
  int ns, nm;

  
  initial 
    for (ns=0; ns<NUM_EXP; ns++) begin
      path_in  = $sformatf("inp_%0d.txt",ns);
      file_in  = $fopen(path_in , "w");

      path_exp = $sformatf("exp_%0d.txt",ns);
      file_exp = $fopen(path_exp, "w");

      // Randomize x
      $display("%0d) xm:", ns);
      for (int r=0; r<R; r++) begin
        $write("| ");
        for (int k=0; k<K; k++) begin
          xm[ns][r][k] = WX'($urandom_range(0,2**WX-1));
          $write("%d ",  $signed(xm[ns][r][k]));
        end 
        $write("|\n");
      end

      // Randomize k
      $display("%0d) km:", ns);
      for (int k=0; k<K; k++) begin
        $write("| ");
        for (int c=0; c<R; c++) begin
          km[ns][k][c] = WK'($urandom_range(0,2**WK-1));
          $write("%d ",  $signed(km[ns][k][c]));
        end
        $write("|\n");
      end

      // Concat and write to file
      for (int k=0; k<K; k++) begin

        for (int r=0; r<R; r++)
          x_row[r] = xm[ns][r][k];
        for (int c=0; c<C; c++)
          k_col[c] = km[ns][k][c];

        xk2 = {k_col, x_row};

        for (int i=0; i<WXK_BUS/2; i++)
          $fdisplay(file_in, "%d", xk2[i]);
      end

      // Expected y
      for (int r=0; r<R; r++)
        for (int c=0; c<C; c++) begin
          for (int k=0; k<K; k++) begin
            am[ns][k][r][c] = $signed(xm[ns][r][k]) * $signed(km[ns][k][c]) + $signed(am[ns][k-1][r][c]);
          end
          ym[ns][r][c] = am[ns][K-1][r][c];
        end
      
      $display("%0d) ym:", ns);
      for (int r=0; r<R; r++) begin
        $write("| ");
        for (int c=0; c<C; c++)
          $write("%d ",  $signed(ym[ns][r][c]));
        $write("|\n");
      end


      for (int c=0; c<C; c++) // last column comes out first
        for (int r=0; r<R; r++)
          $fdisplay(file_exp, "%d",  $signed(ym[ns][r][c]));
      
      $fclose(file_in);
      $fclose(file_exp);

      source.axis_push (path_in);
    end

  initial begin
    $dumpfile ("axis_tb.vcd"); $dumpvars;

    rstn = 0;
    repeat(2) @(posedge clk);
    rstn = 1;

    for (nm=0; nm<NUM_EXP; nm++) begin
      path_out = $sformatf("out_%0d.txt",nm);
      sink.axis_pull (path_out);
      $display("Done axis pull");

      file_out = $fopen(path_out, "r");
      for (int c=0; c<C; c++) // output is in row-major order, not column-major
        for (int r=0; r<R; r++) begin
          status = $fscanf(file_out,"%d\n", y_val);
          y_exp = $signed(ym[nm][r][c]);
          assert (y_val == y_exp) else $fatal(1,"Output does not match, nm=%d, y_val=(%d) != y_exp(%d)", nm, $signed(y_val), $signed(y_exp));
        end
      $fclose(file_out);
    end
    $finish();
  end

  // debug signals
  struct { logic [WX-1:0] d; logic v;         } xi [R][C];
  struct { logic [WK-1:0] d; logic v;         } ki [R][C];
  struct { logic [WM-1:0] d; logic v; logic f;} mo [R][C];
  struct { logic [WY-1:0] d; logic v, vin, cf;    } ao [R][C];
  struct { logic [WY-1:0] d; logic v, l, cp, cl, cf;      } ro [R][C];

  genvar r,c;
  for (r=0; r<R; r++)
    for (c=0; c<C; c++)
      always_comb begin

        xi[r][c].d = DUT.xi[r][c];
        ki[r][c].d = DUT.ki[r][c];
        mo[r][c].d = DUT.mo[r][c];
        ao[r][c].d = DUT.ao[r][c];
        ro[r][c].d = DUT.ro[r][c];

        xi[r][c].v   = DUT.valid[`DIAG(r,c)];
        ki[r][c].v   = DUT.valid[`DIAG(r,c)];
        mo[r][c].v   = DUT.valid[LM+`DIAG(r,c)];
        mo[r][c].f   = DUT.m_first[`DIAG(r,c)];
        ao[r][c].vin = DUT.valid_last[LM+LA+`DIAG(r,c)];

        ao[r][c].v   = DUT.ad_valid[`DIAG(r,c)];
        ao[r][c].cf  = DUT.conflict[`DIAG(r,c)];
        ro[r][c].v   = DUT.r_valid [`DIAG(r,c)];
        ro[r][c].l   = DUT.r_last  [`DIAG(r,c)];
        ro[r][c].cp  = DUT.reg_copy[`DIAG(r,c)];
        ro[r][c].cl  = DUT.reg_clear[`DIAG(r,c)];
        ro[r][c].cf  = DUT.conflict[`DIAG(r,c)];
      end
endmodule 