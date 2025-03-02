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
          s_keep[i] <= 1;
          i_words += 1;
        end else begin
          s_data[i] <= 'x;
          s_keep[i] <= 0;
        end

      do @(posedge clk); while (!s_ready); // wait for s_data to be accepted
      
      #1ps;
      // clear s_valid and s_data
      s_valid <= 0;
      s_data  <= 'x;
    end
  endtask

  task automatic read_file_to_queue (string filepath, output [WORD_W-1:0] q [$]);
    int fd, status;
    logic signed [WORD_W-1:0] val;
    q = {};

    fd = $fopen(filepath, "r");
    if (fd == 0) $fatal(1, "Error opening file %s", filepath);

    while (!$feof(fd)) begin
      status = $fscanf(fd,"%d\n", val);
      q.push_back(val);
    end
    $fclose(fd);
  endtask

  task automatic get_random_queue (output logic [WORD_W-1:0] q [$], input int n_words);
    q = {};
    repeat(n_words) q.push_back(WORD_W'($urandom_range(0,2**WORD_W-1)));
  endtask

endmodule


module AXIS_Sink #(
  parameter  WORD_W=8, BUS_W=32, PROB_READY=20,
             WORDS_PER_BEAT = BUS_W/WORD_W
)(
  input  logic clk, m_valid, m_last,
  output logic m_ready = 0,
  input  logic [WORDS_PER_BEAT-1:0] m_keep,
  input  logic [WORDS_PER_BEAT-1:0][WORD_W-1:0] m_data
);

  task automatic axis_pull_packet(output logic [WORD_W-1:0] packet [$]);
    
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

  task automatic write_queue_to_file (string filepath, input logic [WORD_W-1:0] q [$]);
    int fd;
    fd = $fopen(filepath, "w");
    if (fd == 0) $fatal(1, "Error opening file %s", filepath);
    foreach (q[i]) $fwrite(fd, "%d\n", q[i]);
    $fclose(fd);
  endtask
endmodule


module axis_tb;
  localparam  WORD_W=8, BUS_W=32,
              WORDS_PER_BEAT=BUS_W/WORD_W,
              PROB_VALID=1, PROB_READY=10,
              CLK_PERIOD=10, NUM_EXP=20;

  logic clk=0, rstn=0;
  initial forever #(CLK_PERIOD/2) clk = ~clk;

  logic s_valid, s_ready, m_valid, m_ready, s_last, m_last;
  logic [WORDS_PER_BEAT-1:0] s_keep, m_keep;
  logic [WORDS_PER_BEAT-1:0][WORD_W-1:0] s_data, m_data;
  AXIS_Source #(.WORD_W(WORD_W), .BUS_W(BUS_W), .PROB_VALID(PROB_VALID)) source (.*);
  AXIS_Sink   #(.WORD_W(WORD_W), .BUS_W(BUS_W), .PROB_READY(PROB_READY)) sink   (.*);
  assign {s_ready, m_valid, m_data, m_keep, m_last} = {m_ready, s_valid, s_data, s_keep, s_last};

  typedef logic [WORD_W-1:0] packet_t [$];

`ifndef FILE_TEST
  packet_t tx_packets [NUM_EXP], rx_packets [NUM_EXP];
`else 
  packet_t tx_packet, rx_packet, temp, exp;
  string path_tx, path_rx;
`endif

  int n_words;

  initial begin
    $dumpfile ("dump.vcd"); $dumpvars;
    repeat(5) @(posedge clk);
    rstn <= 1;

    for (int n=0; n<NUM_EXP; n++) begin
      n_words = $urandom_range(1, 100);

`ifndef FILE_TEST
      source.get_random_queue(tx_packets[n], n_words);
      source.axis_push_packet(tx_packets[n]);
`else
      path_tx = $sformatf("tx_%0d.txt", n);
      // Prepare a random file
      source.get_random_queue(temp, n_words);
      sink.write_queue_to_file(path_tx, temp);
      // Read the file back & push
      source.read_file_to_queue(path_tx, tx_packet);
      source.axis_push_packet(tx_packet);
`endif
    end
  end

  initial begin
    $display("Waiting for packets to be received...");
    for (int n=0; n<NUM_EXP; n++) begin

`ifndef FILE_TEST
      sink.axis_pull_packet(rx_packets[n]);
      if(rx_packets[n] == tx_packets[n])
        $display("Packet[%0d]: Outputs match: %p\n", n, rx_packets[n]);
      else begin
        $display("Packet[%0d]: Expected: \n%p \n != \n Received: \n%p", n, tx_packets[n], rx_packets[n]);
        $fatal(1, "Failed");
      end

`else
      path_rx = $sformatf("rx_%0d.txt", n);

      sink.axis_pull_packet(rx_packet);
      sink.write_queue_to_file(path_rx, rx_packet);

      source.read_file_to_queue(path_tx, exp);
      if(exp == rx_packet)
        $display("Packet[%0d]: Outputs match: %p\n", n, rx_packet);
      else begin
        $display("Packet[%0d]: Expected: \n%p \n != \n Received: \n%p", n, exp, rx_packet);
        $fatal(1, "Failed");
      end
`endif

    end
    $finish();
  end
endmodule