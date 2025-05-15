`timescale 1ns / 1ps

//              Columns (col)
//          +-------+-------+-------+-------+
// Row r=0 | x[0]  | x[1]  | x[2]  | x[3]  |   <-- Inputs (no delay)
//          +-------+-------+-------+-------+
// Row r=1 |       | b[1,1]| b[1,2]| b[1,3]|   <-- 1-cycle delayed values
//          +-------+-------+-------+-------+
// Row r=2 |       |       | b[2,2]| b[2,3]|   <-- 2-cycle delayed values
//          +-------+-------+-------+-------+
// Row r=3 |       |       |       | b[3,3]|   <-- 3-cycle delayed value
//          +-------+-------+-------+-------+


module tri_buffer #(
    parameter int unsigned Width = 8,
    parameter int unsigned Size  = 4
) (
    input  logic                       clk_i,
    input  logic                       rst_ni,
    input  logic                       en_i,
    input  logic [Size-1:0][Width-1:0] x_i,
    output logic [Size-1:0][Width-1:0] y_o
);
  logic signed [Size-1:0][Size-1:0][Width-1:0] buffer; // (R,C), r=0 is comb, r=1 has Size-1 reg, r=2 has Size-2 reg, etc

  assign buffer[0] = x_i;  //r==0: load input into 0th row

  for (genvar row = 1; row < Size; row++) begin : gen_row  // each row is a delay
    for (genvar col = row; col < Size; col++) begin : gen_col  // each column is (C-r) elements wide
      always_ff @(posedge clk_i)
        if (!rst_ni) buffer[row][col] <= 0;
        else if (en_i) buffer[row][col] <= buffer[row-1][col];
    end
  end

  for (genvar col = 0; col < Size; col++) begin : gen_output  // read output from diagonal
    assign y_o[col] = buffer[col][col];  // read output from diagonal
  end
endmodule
