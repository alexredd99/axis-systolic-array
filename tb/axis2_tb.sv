`timescale 1ns/1ps
`define CEIL(a, b) (((a) + (b) - 1) / (b))

module AXIS_Source #(
  parameter  WORD_W=8, BUS_W=8, PROB_VALID=20,
  localparam WORDS_PER_BEAT = BUS_W/WORD_W
)(
  input  logic clk, s_ready,
  output logic s_valid = 0, s_last = 0,
  output logic [WORDS_PER_BEAT-1:0] s_keep = '0,
  output logic [WORDS_PER_BEAT-1:0][WORD_W-1:0] s_data = 'x
);
  task automatic axis_push_packet(input logic [WORD_W-1:0] packet [$]);

    int total_words = packet.size();
    int n_beats = `CEIL(total_words, WORDS_PER_BEAT);
    int i_words = 0;

    for (int ib=0; ib < n_beats; ib++) begin
       // randomize s_valid and wait
      while ($urandom_range(0,99) >= PROB_VALID) @(posedge clk);

      #1ps; // V_erilator wants delays
      s_valid <= 1;
      s_last  <= ib == n_beats-1;

      for (int i=0; i<WORDS_PER_BEAT; i++) 
        if (i_words < total_words) begin
          s_data[i] <= packet[i_words];
          s_keep    <= 1;
          i_words += 1;
        end else begin
          s_data[i] <= 'x;
          s_keep    <= 0;
        end

      do @(posedge clk); while (!s_ready); // wait for s_data to be accepted
      
      #1ps;
      // clear s_valid and s_data
      s_valid <= 0;
      s_data  <= 'x;
    end
  endtask
endmodule


module AXIS_Sink #(
  parameter  WORD_W=8, BUS_W=8, PROB_READY=20,
             WORDS_PER_BEAT = BUS_W/WORD_W
)(
  input  logic clk, m_valid, m_last,
  output logic m_ready = 0,
  input  logic [WORDS_PER_BEAT-1:0] m_keep,
  input  logic [WORDS_PER_BEAT-1:0][WORD_W-1:0] m_data
);

  task automatic axis_pull_packet(output [WORD_W-1:0] packet [$]);
    
    int i_words = 0;
    bit done = 0;
    packet = {};

    // loop over beats
    while (!done) begin

      do begin 
        #1ps m_ready <= 0; // keep m_ready low with probability (1-PROB_READY)
        while ($urandom_range(0,99) >= PROB_READY) @(posedge clk);
        #1ps m_ready <= 1;
        @(posedge clk); // keep m_ready high for one cycle
      end while (!m_valid); // if m_valid is high, break out of loop
      
      // can sample everything
      done = m_last;
      for (int i=0; i<WORDS_PER_BEAT; i++) 
        if (m_keep[i]) begin
          packet.push_back(m_data[i]);
          i_words += 1;
        end
    end
  endtask
endmodule

module axis_tb;

  localparam  WORD_W=8, BUS_W=8,
              WORDS_PER_BEAT=BUS_W/WORD_W,
              PROB_VALID=1, PROB_READY=10,
              CLK_PERIOD=10, NUM_EXP=20;

  logic clk=0, rstn;
  logic s_valid, s_ready, m_valid, m_ready, s_last, m_last;
  logic [WORDS_PER_BEAT-1:0] s_keep, m_keep;
  logic [WORDS_PER_BEAT-1:0][WORD_W-1:0] s_data, m_data;
  logic [WORDS_PER_BEAT-1:0][WORD_W-1:0] in_beat;

  initial forever #(CLK_PERIOD/2) clk = ~clk;

  AXIS_Source #(.WORD_W(WORD_W), .BUS_W(BUS_W), .PROB_VALID(PROB_VALID)) source (.*);
  AXIS_Sink   #(.WORD_W(WORD_W), .BUS_W(BUS_W), .PROB_READY(PROB_READY)) sink   (.*);

  assign s_ready = m_ready;
  assign m_valid = s_valid;
  assign m_data = s_data;
  assign m_keep = s_keep;
  assign m_last = s_last;

  // logic [N_BEATS-1:0][WORDS_PER_BEAT-1:0][WORD_W-1:0] tx_packet, rx_packet;

  logic [WORD_W-1:0] tx_packets [NUM_EXP][$];
  logic [WORD_W-1:0] tx_packet [$];
  logic [WORD_W-1:0] rx_packets [NUM_EXP][$];
  int n_words;

  initial begin
    $dumpfile ("dump.vcd"); $dumpvars;
    rstn = 0;
    repeat(5) @(posedge clk);
    rstn <= 1;
    repeat(5) @(posedge clk);

    // initialize reference data beats
    for (int n=0; n<NUM_EXP; n++) begin
      n_words = $urandom_range(1, 100);
      tx_packet = {};
      repeat(n_words) tx_packet.push_back(WORD_W'($urandom_range(0,2**WORD_W-1)));
      tx_packets[n] = tx_packet;
      source.axis_push_packet(tx_packet);
    end
  end

  initial begin
    $display("Waiting for packets to be received...");
    for (int n=0; n<NUM_EXP; n++) begin
      sink.axis_pull_packet(rx_packets[n]);
      if(rx_packets[n] == tx_packets[n])
        $display("Packet[%0d]: Outputs match: %p", n, rx_packets[n]);
      else begin
        $display("Packet[%0d]: Expected: \n%p \n != \n Received: \n%p", n, tx_packets[n], rx_packets[n]);
        $fatal(1, "Failed");
      end
    end
    $finish();
  end
endmodule