`timescale 1ns/1ps
`define DIAG(a, b) (a+b)

module axis_sa_tb;
  localparam 
    R          = 2, // Rows of SA == rows of output matrix
    C          = 2, // Cols of SA == cols of output matrix
    K_MIN      = 5, // Cols of matrix_k and rows of matrix_k
    K_MAX      = 30,
    WX         = 8, // word width of matrix_k
    WK         = 4, // word width of matrix_k
    LM         = 2, // latency of multiplier
    LA         = 3, // latency of accumulator
    WM         = WX + WK,            // word width of multiplier
    WY         = WM + $clog2(K_MAX), // word width of accumulator
    P_VALID    = 1,  // Probability with which s_valid is toggled
    P_READY    = 5, // Probability with which m_ready is toggled
    CLK_PERIOD = 10,
    NUM_EXP    = 50;  // Number of experiments

  logic clk=0, rstn=0;
  initial forever #(CLK_PERIOD/2) clk = ~clk;

  // Systolic Array
  logic s_ready, sk_valid, sk_last, sx_valid, sx_last, m_ready, m_valid, m_last;
  logic [R-1:0][WX-1:0] sx_data;
  logic [C-1:0][WK-1:0] sk_data;
  logic [R-1:0][WY-1:0] m_data;

  // Synchronize two streams
  wire s_valid  = sx_valid && sk_valid;
  wire s_last   = sx_last  && sk_last;
  wire sx_ready = sk_valid && s_ready;
  wire sk_ready = sx_valid && s_ready;
  wire [R-1:0] m_keep = '1;

  axis_sa #(.R(R), .C(C), .WX(WX), .WK(WK), .WY(WY), .LM(LM), .LA(LA)) DUT (.*);

  axis_source #(.WORD_W(WX), .BUS_W(WX*R), .PROB_VALID(P_VALID)) source_x (.clk(clk), .s_valid(sx_valid), .s_ready(sx_ready), .s_last(sx_last), .s_keep(), .s_data(sx_data));
  axis_source #(.WORD_W(WK), .BUS_W(WK*C), .PROB_VALID(P_VALID)) source_k (.clk(clk), .s_valid(sk_valid), .s_ready(sk_ready), .s_last(sk_last), .s_keep(), .s_data(sk_data));
  axis_sink   #(.WORD_W(WY), .BUS_W(WY*R), .PROB_READY(P_READY)) sink_y   (.*);

  typedef logic signed [WX-1:0] xp_t [$];
  typedef logic signed [WK-1:0] kp_t [$];
  typedef logic signed [WY-1:0] yp_t [$];

  xp_t x_packets [NUM_EXP], x_packet;
  kp_t k_packets [NUM_EXP], k_packet;
  yp_t y_packets [NUM_EXP], e_packet, e_packets [NUM_EXP];

  logic signed [WY-1:0] val;
  int rand_k;

  initial begin
    $dumpfile ("dump.vcd"); $dumpvars;
    repeat(5) @(posedge clk);
    rstn <= 1;

    for (int n=0; n<NUM_EXP; n++) begin
      x_packet = {};
      k_packet = {};
      rand_k = $urandom_range(K_MIN, K_MAX);
      source_k.get_random_queue(k_packet, rand_k*C); // (K,C)
      source_x.get_random_queue(x_packet, rand_k*R); // (K,R)

      // Expected output
      e_packet = {};
      for (int c=0; c<C; c++)
        for (int r=0; r<R; r++) begin
          val = 0;
          for (int k=0; k<rand_k; k++) 
            val = $signed(val) + $signed(k_packet[k*C+c]) * $signed(x_packet[k*R+r]);
          e_packet.push_back(val);
        end
      x_packets[n] = x_packet;
      k_packets[n] = k_packet;
      e_packets[n] = e_packet;

      //Multithread push
      fork
        source_k.axis_push_packet(k_packet);
        source_x.axis_push_packet(x_packet);
      join
    end
  end

  initial begin
    wait(rstn);
    $display("Waiting for packets to be received...");
    for (int n=0; n<NUM_EXP; n++) begin
      sink_y.axis_pull_packet(y_packets[n]);

      if(y_packets[n] == e_packets[n])
        $display("Packet[%0d]: Outputs match: %p\n", n, y_packets[n]);
      else begin
        $display("Packet[%0d]: Expected: \n%p \n != \n Received: \n%p", n, e_packets[n], y_packets[n]);
        $fatal(1, "Failed");
      end
    end
    $finish();
  end

endmodule 