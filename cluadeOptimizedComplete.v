module alphaevolve_4x4_optimized (
    input clk,
    input rst_n,
    input start,
    input load_en,
    input read_en,
    input [31:0] data_in,
    input [4:0] addr_in,
    output reg [31:0] data_out,
    output reg done
);

  parameter FRAC_BITS = 16;
  parameter IDLE = 3'b000, LOAD = 3'b001, COMPUTE_A = 3'b010, COMPUTE_B = 3'b011, COMPUTE_M = 3'b100, COMPUTE_C = 3'b101, DONE = 3'b110;

  reg [2:0] state, next_state;
  reg [5:0] compute_index;

  (* ram_style = "block" *) reg [63:0] a[0:47];
  (* ram_style = "block" *) reg [63:0] b[0:47];
  (* ram_style = "block" *) reg [63:0] m[0:47];

  reg [31:0] A_reg[0:15];
  reg [31:0] B_reg[0:15];
  reg [31:0] C[0:15];

  // Separate coefficient arrays for A and B computations


  reg [31:0] coeff_real_a[0:47][0:7];
  reg [31:0] coeff_imag_a[0:47][0:7];
  reg [3:0] idx_a[0:47][0:7];

  reg [31:0] coeff_real_b[0:47][0:7];
  reg [31:0] coeff_imag_b[0:47][0:7];
  reg [3:0] idx_b[0:47][0:7];

  reg [7:0] idx_m[0:15][0:7];

  integer i, j;

  // Temporary variables for computation


  reg [63:0] temp_accum;
  reg signed [31:0] temp_sum;

  // Constants


  localparam HALF = 32'h00008000;  // 0.5 in Q16.16


  localparam NEG_HALF = 32'hFFFF8000;  // -0.5 in Q16.16



  // Complex arithmetic functions


  function [63:0] complex_add_coeff;
    input [31:0] coeff_r, coeff_i;
    input [31:0] val;
    input [63:0] accum;
    reg signed [31:0] c_r, c_i, v_r, v_i;
    reg signed [63:0] real_part, imag_part;
    begin
      c_r = $signed(coeff_r);
      c_i = $signed(coeff_i);
      v_r = $signed(val[31:16]);
      v_i = $signed(val[15:0]);
      real_part = $signed(accum[63:32]) + ((c_r * v_r - c_i * v_i) >>> FRAC_BITS);
      imag_part = $signed(accum[31:0]) + ((c_r * v_i + c_i * v_r) >>> FRAC_BITS);
      complex_add_coeff = {real_part[31:0], imag_part[31:0]};
    end
  endfunction

  function [63:0] complex_mult;
    input [63:0] a_val, b_val;
    reg signed [31:0] a_r, a_i, b_r, b_i;
    reg signed [63:0] real_p, imag_p;
    begin
      a_r = $signed(a_val[63:32]);
      a_i = $signed(a_val[31:0]);
      b_r = $signed(b_val[63:32]);
      b_i = $signed(b_val[31:0]);
      real_p = (a_r * b_r - a_i * b_i) >>> FRAC_BITS;
      imag_p = (a_r * b_i + a_i * b_r) >>> FRAC_BITS;
      complex_mult = {real_p[31:0], imag_p[31:0]};
    end
  endfunction

  // Initialize coefficient tables


  initial begin
    // Initialize all arrays to zero


    for (i = 0; i < 48; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        coeff_real_a[i][j] = 32'h0;
        coeff_imag_a[i][j] = 32'h0;
        coeff_real_b[i][j] = 32'h0;
        coeff_imag_b[i][j] = 32'h0;
        idx_a[i][j] = 4'h0;
        idx_b[i][j] = 4'h0;
      end
    end

    for (i = 0; i < 16; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        idx_m[i][j] = 8'h0;
      end
    end

    // Generated coefficient initialization


    // A coefficients

    // a0 computation

    coeff_real_a[0][0] = 32'h00010000;  // 1.0

    coeff_imag_a[0][0] = 32'h00000000;  // 0.0j

    idx_a[0][0] = 4'd0;
    coeff_real_a[0][1] = 32'h00000000;  // 0.0

    coeff_imag_a[0][1] = 32'h00008000;  // 0.5j

    idx_a[0][1] = 4'd0;
    coeff_real_a[0][2] = 32'h00000000;  // 0.0

    coeff_imag_a[0][2] = 32'h00008000;  // 0.5j

    idx_a[0][2] = 4'd1;
    coeff_real_a[0][3] = 32'h00000000;  // 0.0

    coeff_imag_a[0][3] = 32'hFFFF8000;  // -0.5j

    idx_a[0][3] = 4'd4;
    coeff_real_a[0][4] = 32'h00000000;  // 0.0

    coeff_imag_a[0][4] = 32'hFFFF8000;  // -0.5j

    idx_a[0][4] = 4'd5;
    coeff_real_a[0][5] = 32'h00000000;  // 0.0

    coeff_imag_a[0][5] = 32'hFFFF8000;  // -0.5j

    idx_a[0][5] = 4'd8;
    coeff_real_a[0][6] = 32'h00000000;  // 0.0

    coeff_imag_a[0][6] = 32'hFFFF8000;  // -0.5j

    idx_a[0][6] = 4'd9;
    coeff_real_a[0][7] = 32'h00000000;  // 0.0

    coeff_imag_a[0][7] = 32'hFFFF8000;  // -0.5j

    idx_a[0][7] = 4'd12;

    // a1 computation

    coeff_real_a[1][0] = 32'h00010000;  // 1.0

    coeff_imag_a[1][0] = 32'h00000000;  // 0.0j

    idx_a[1][0] = 4'd0;
    coeff_real_a[1][1] = 32'h00000000;  // 0.0

    coeff_imag_a[1][1] = 32'h00008000;  // 0.5j

    idx_a[1][1] = 4'd0;
    coeff_real_a[1][2] = 32'h00000000;  // 0.0

    coeff_imag_a[1][2] = 32'h00008000;  // 0.5j

    idx_a[1][2] = 4'd3;
    coeff_real_a[1][3] = 32'h00000000;  // 0.0

    coeff_imag_a[1][3] = 32'h00008000;  // 0.5j

    idx_a[1][3] = 4'd4;
    coeff_real_a[1][4] = 32'h00000000;  // 0.0

    coeff_imag_a[1][4] = 32'h00008000;  // 0.5j

    idx_a[1][4] = 4'd7;
    coeff_real_a[1][5] = 32'h00000000;  // 0.0

    coeff_imag_a[1][5] = 32'hFFFF8000;  // -0.5j

    idx_a[1][5] = 4'd8;
    coeff_real_a[1][6] = 32'h00000000;  // 0.0

    coeff_imag_a[1][6] = 32'hFFFF8000;  // -0.5j

    idx_a[1][6] = 4'd11;
    coeff_real_a[1][7] = 32'h00000000;  // 0.0

    coeff_imag_a[1][7] = 32'hFFFF8000;  // -0.5j

    idx_a[1][7] = 4'd12;

    // a2 computation

    coeff_real_a[2][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[2][0] = 32'h00000000;  // 0.0j

    idx_a[2][0] = 4'd1;
    coeff_real_a[2][1] = 32'h00008000;  // 0.5

    coeff_imag_a[2][1] = 32'h00000000;  // 0.0j

    idx_a[2][1] = 4'd2;
    coeff_real_a[2][2] = 32'h00000000;  // 0.0

    coeff_imag_a[2][2] = 32'hFFFF8000;  // -0.5j

    idx_a[2][2] = 4'd5;
    coeff_real_a[2][3] = 32'h00000000;  // 0.0

    coeff_imag_a[2][3] = 32'h00008000;  // 0.5j

    idx_a[2][3] = 4'd6;
    coeff_real_a[2][4] = 32'h00000000;  // 0.0

    coeff_imag_a[2][4] = 32'h00008000;  // 0.5j

    idx_a[2][4] = 4'd9;
    coeff_real_a[2][5] = 32'h00000000;  // 0.0

    coeff_imag_a[2][5] = 32'hFFFF8000;  // -0.5j

    idx_a[2][5] = 4'd10;
    coeff_real_a[2][6] = 32'h00000000;  // 0.0

    coeff_imag_a[2][6] = 32'hFFFF8000;  // -0.5j

    idx_a[2][6] = 4'd13;
    coeff_real_a[2][7] = 32'h00000000;  // 0.0

    coeff_imag_a[2][7] = 32'h00008000;  // 0.5j

    idx_a[2][7] = 4'd14;

    // a3 computation

    coeff_real_a[3][0] = 32'h00000000;  // 0.0

    coeff_imag_a[3][0] = 32'hFFFF8000;  // -0.5j

    idx_a[3][0] = 4'd0;
    coeff_real_a[3][1] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[3][1] = 32'h00000000;  // 0.0j

    idx_a[3][1] = 4'd1;
    coeff_real_a[3][2] = 32'h00008000;  // 0.5

    coeff_imag_a[3][2] = 32'h00000000;  // 0.0j

    idx_a[3][2] = 4'd2;
    coeff_real_a[3][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[3][3] = 32'h00000000;  // 0.0j

    idx_a[3][3] = 4'd3;
    coeff_real_a[3][4] = 32'h00000000;  // 0.0

    coeff_imag_a[3][4] = 32'h00008000;  // 0.5j

    idx_a[3][4] = 4'd4;
    coeff_real_a[3][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[3][5] = 32'h00000000;  // 0.0j

    idx_a[3][5] = 4'd5;
    coeff_real_a[3][6] = 32'h00008000;  // 0.5

    coeff_imag_a[3][6] = 32'h00000000;  // 0.0j

    idx_a[3][6] = 4'd6;
    coeff_real_a[3][7] = 32'h00008000;  // 0.5

    coeff_imag_a[3][7] = 32'h00000000;  // 0.0j

    idx_a[3][7] = 4'd7;

    // a4 computation

    coeff_real_a[4][0] = 32'h00010000;  // 1.0

    coeff_imag_a[4][0] = 32'h00000000;  // 0.0j

    idx_a[4][0] = 4'd0;
    coeff_real_a[4][1] = 32'h00000000;  // 0.0

    coeff_imag_a[4][1] = 32'h00008000;  // 0.5j

    idx_a[4][1] = 4'd0;
    coeff_real_a[4][2] = 32'h00000000;  // 0.0

    coeff_imag_a[4][2] = 32'hFFFF8000;  // -0.5j

    idx_a[4][2] = 4'd1;
    coeff_real_a[4][3] = 32'h00000000;  // 0.0

    coeff_imag_a[4][3] = 32'h00008000;  // 0.5j

    idx_a[4][3] = 4'd4;
    coeff_real_a[4][4] = 32'h00000000;  // 0.0

    coeff_imag_a[4][4] = 32'hFFFF8000;  // -0.5j

    idx_a[4][4] = 4'd5;
    coeff_real_a[4][5] = 32'h00000000;  // 0.0

    coeff_imag_a[4][5] = 32'h00008000;  // 0.5j

    idx_a[4][5] = 4'd8;
    coeff_real_a[4][6] = 32'h00000000;  // 0.0

    coeff_imag_a[4][6] = 32'hFFFF8000;  // -0.5j

    idx_a[4][6] = 4'd9;
    coeff_real_a[4][7] = 32'h00000000;  // 0.0

    coeff_imag_a[4][7] = 32'hFFFF8000;  // -0.5j

    idx_a[4][7] = 4'd12;

    // a5 computation

    coeff_real_a[5][0] = 32'h00010000;  // 1.0

    coeff_imag_a[5][0] = 32'h00000000;  // 0.0j

    idx_a[5][0] = 4'd0;
    coeff_real_a[5][1] = 32'h00000000;  // 0.0

    coeff_imag_a[5][1] = 32'hFFFF8000;  // -0.5j

    idx_a[5][1] = 4'd2;
    coeff_real_a[5][2] = 32'h00000000;  // 0.0

    coeff_imag_a[5][2] = 32'hFFFF8000;  // -0.5j

    idx_a[5][2] = 4'd3;
    coeff_real_a[5][3] = 32'h00000000;  // 0.0

    coeff_imag_a[5][3] = 32'hFFFF8000;  // -0.5j

    idx_a[5][3] = 4'd6;
    coeff_real_a[5][4] = 32'h00000000;  // 0.0

    coeff_imag_a[5][4] = 32'hFFFF8000;  // -0.5j

    idx_a[5][4] = 4'd7;
    coeff_real_a[5][5] = 32'h00000000;  // 0.0

    coeff_imag_a[5][5] = 32'h00008000;  // 0.5j

    idx_a[5][5] = 4'd10;
    coeff_real_a[5][6] = 32'h00000000;  // 0.0

    coeff_imag_a[5][6] = 32'h00008000;  // 0.5j

    idx_a[5][6] = 4'd11;
    coeff_real_a[5][7] = 32'h00000000;  // 0.0

    coeff_imag_a[5][7] = 32'hFFFF8000;  // -0.5j

    idx_a[5][7] = 4'd14;

    // a6 computation

    coeff_real_a[6][0] = 32'h00000000;  // 0.0

    coeff_imag_a[6][0] = 32'h00008000;  // 0.5j

    idx_a[6][0] = 4'd0;
    coeff_real_a[6][1] = 32'h00008000;  // 0.5

    coeff_imag_a[6][1] = 32'h00000000;  // 0.0j

    idx_a[6][1] = 4'd3;
    coeff_real_a[6][2] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[6][2] = 32'h00000000;  // 0.0j

    idx_a[6][2] = 4'd4;
    coeff_real_a[6][3] = 32'h00000000;  // 0.0

    coeff_imag_a[6][3] = 32'h00008000;  // 0.5j

    idx_a[6][3] = 4'd7;
    coeff_real_a[6][4] = 32'h00008000;  // 0.5

    coeff_imag_a[6][4] = 32'h00000000;  // 0.0j

    idx_a[6][4] = 4'd8;
    coeff_real_a[6][5] = 32'h00000000;  // 0.0

    coeff_imag_a[6][5] = 32'hFFFF8000;  // -0.5j

    idx_a[6][5] = 4'd11;
    coeff_real_a[6][6] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[6][6] = 32'h00000000;  // 0.0j

    idx_a[6][6] = 4'd12;
    coeff_real_a[6][7] = 32'h00000000;  // 0.0

    coeff_imag_a[6][7] = 32'h00008000;  // 0.5j

    idx_a[6][7] = 4'd15;

    // a7 computation

    coeff_real_a[7][0] = 32'h00010000;  // 1.0

    coeff_imag_a[7][0] = 32'h00000000;  // 0.0j

    idx_a[7][0] = 4'd0;
    coeff_real_a[7][1] = 32'h00000000;  // 0.0

    coeff_imag_a[7][1] = 32'h00008000;  // 0.5j

    idx_a[7][1] = 4'd0;
    coeff_real_a[7][2] = 32'h00000000;  // 0.0

    coeff_imag_a[7][2] = 32'hFFFF8000;  // -0.5j

    idx_a[7][2] = 4'd1;
    coeff_real_a[7][3] = 32'h00000000;  // 0.0

    coeff_imag_a[7][3] = 32'hFFFF8000;  // -0.5j

    idx_a[7][3] = 4'd4;
    coeff_real_a[7][4] = 32'h00000000;  // 0.0

    coeff_imag_a[7][4] = 32'h00008000;  // 0.5j

    idx_a[7][4] = 4'd5;
    coeff_real_a[7][5] = 32'h00000000;  // 0.0

    coeff_imag_a[7][5] = 32'hFFFF8000;  // -0.5j

    idx_a[7][5] = 4'd8;
    coeff_real_a[7][6] = 32'h00000000;  // 0.0

    coeff_imag_a[7][6] = 32'h00008000;  // 0.5j

    idx_a[7][6] = 4'd9;
    coeff_real_a[7][7] = 32'h00000000;  // 0.0

    coeff_imag_a[7][7] = 32'h00008000;  // 0.5j

    idx_a[7][7] = 4'd12;

    // a8 computation

    coeff_real_a[8][0] = 32'h00000000;  // 0.0

    coeff_imag_a[8][0] = 32'hFFFF8000;  // -0.5j

    idx_a[8][0] = 4'd0;
    coeff_real_a[8][1] = 32'h00000000;  // 0.0

    coeff_imag_a[8][1] = 32'hFFFF8000;  // -0.5j

    idx_a[8][1] = 4'd1;
    coeff_real_a[8][2] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[8][2] = 32'h00000000;  // 0.0j

    idx_a[8][2] = 4'd2;
    coeff_real_a[8][3] = 32'h00000000;  // 0.0

    coeff_imag_a[8][3] = 32'hFFFF8000;  // -0.5j

    idx_a[8][3] = 4'd3;
    coeff_real_a[8][4] = 32'h00008000;  // 0.5

    coeff_imag_a[8][4] = 32'h00000000;  // 0.0j

    idx_a[8][4] = 4'd4;
    coeff_real_a[8][5] = 32'h00008000;  // 0.5

    coeff_imag_a[8][5] = 32'h00000000;  // 0.0j

    idx_a[8][5] = 4'd5;
    coeff_real_a[8][6] = 32'h00000000;  // 0.0

    coeff_imag_a[8][6] = 32'hFFFF8000;  // -0.5j

    idx_a[8][6] = 4'd6;
    coeff_real_a[8][7] = 32'h00008000;  // 0.5

    coeff_imag_a[8][7] = 32'h00000000;  // 0.0j

    idx_a[8][7] = 4'd7;

    // a9 computation

    coeff_real_a[9][0] = 32'h00010000;  // 1.0

    coeff_imag_a[9][0] = 32'h00000000;  // 0.0j

    idx_a[9][0] = 4'd0;
    coeff_real_a[9][1] = 32'h00000000;  // 0.0

    coeff_imag_a[9][1] = 32'h00008000;  // 0.5j

    idx_a[9][1] = 4'd0;
    coeff_real_a[9][2] = 32'h00000000;  // 0.0

    coeff_imag_a[9][2] = 32'hFFFF8000;  // -0.5j

    idx_a[9][2] = 4'd3;
    coeff_real_a[9][3] = 32'h00000000;  // 0.0

    coeff_imag_a[9][3] = 32'h00008000;  // 0.5j

    idx_a[9][3] = 4'd4;
    coeff_real_a[9][4] = 32'h00000000;  // 0.0

    coeff_imag_a[9][4] = 32'h00008000;  // 0.5j

    idx_a[9][4] = 4'd7;
    coeff_real_a[9][5] = 32'h00000000;  // 0.0

    coeff_imag_a[9][5] = 32'hFFFF8000;  // -0.5j

    idx_a[9][5] = 4'd8;
    coeff_real_a[9][6] = 32'h00000000;  // 0.0

    coeff_imag_a[9][6] = 32'hFFFF8000;  // -0.5j

    idx_a[9][6] = 4'd11;
    coeff_real_a[9][7] = 32'h00000000;  // 0.0

    coeff_imag_a[9][7] = 32'hFFFF8000;  // -0.5j

    idx_a[9][7] = 4'd12;

    // a10 computation

    coeff_real_a[10][0] = 32'h00010000;  // 1.0

    coeff_imag_a[10][0] = 32'h00000000;  // 0.0j

    idx_a[10][0] = 4'd0;
    coeff_real_a[10][1] = 32'h00000000;  // 0.0

    coeff_imag_a[10][1] = 32'h00008000;  // 0.5j

    idx_a[10][1] = 4'd0;
    coeff_real_a[10][2] = 32'h00000000;  // 0.0

    coeff_imag_a[10][2] = 32'hFFFF8000;  // -0.5j

    idx_a[10][2] = 4'd1;
    coeff_real_a[10][3] = 32'h00000000;  // 0.0

    coeff_imag_a[10][3] = 32'h00008000;  // 0.5j

    idx_a[10][3] = 4'd4;
    coeff_real_a[10][4] = 32'h00000000;  // 0.0

    coeff_imag_a[10][4] = 32'hFFFF8000;  // -0.5j

    idx_a[10][4] = 4'd5;
    coeff_real_a[10][5] = 32'h00000000;  // 0.0

    coeff_imag_a[10][5] = 32'hFFFF8000;  // -0.5j

    idx_a[10][5] = 4'd8;
    coeff_real_a[10][6] = 32'h00000000;  // 0.0

    coeff_imag_a[10][6] = 32'h00008000;  // 0.5j

    idx_a[10][6] = 4'd9;
    coeff_real_a[10][7] = 32'h00000000;  // 0.0

    coeff_imag_a[10][7] = 32'h00008000;  // 0.5j

    idx_a[10][7] = 4'd12;

    // a11 computation

    coeff_real_a[11][0] = 32'h00008000;  // 0.5

    coeff_imag_a[11][0] = 32'h00000000;  // 0.0j

    idx_a[11][0] = 4'd0;
    coeff_real_a[11][1] = 32'h00008000;  // 0.5

    coeff_imag_a[11][1] = 32'h00000000;  // 0.0j

    idx_a[11][1] = 4'd1;
    coeff_real_a[11][2] = 32'h00000000;  // 0.0

    coeff_imag_a[11][2] = 32'hFFFF8000;  // -0.5j

    idx_a[11][2] = 4'd2;
    coeff_real_a[11][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[11][3] = 32'h00000000;  // 0.0j

    idx_a[11][3] = 4'd3;
    coeff_real_a[11][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[11][4] = 32'h00000000;  // 0.0j

    idx_a[11][4] = 4'd4;
    coeff_real_a[11][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[11][5] = 32'h00000000;  // 0.0j

    idx_a[11][5] = 4'd5;
    coeff_real_a[11][6] = 32'h00000000;  // 0.0

    coeff_imag_a[11][6] = 32'h00008000;  // 0.5j

    idx_a[11][6] = 4'd6;
    coeff_real_a[11][7] = 32'h00008000;  // 0.5

    coeff_imag_a[11][7] = 32'h00000000;  // 0.0j

    idx_a[11][7] = 4'd7;

    // a12 computation

    coeff_real_a[12][0] = 32'h00010000;  // 1.0

    coeff_imag_a[12][0] = 32'h00000000;  // 0.0j

    idx_a[12][0] = 4'd0;
    coeff_real_a[12][1] = 32'h00000000;  // 0.0

    coeff_imag_a[12][1] = 32'h00008000;  // 0.5j

    idx_a[12][1] = 4'd1;
    coeff_real_a[12][2] = 32'h00000000;  // 0.0

    coeff_imag_a[12][2] = 32'hFFFF8000;  // -0.5j

    idx_a[12][2] = 4'd2;
    coeff_real_a[12][3] = 32'h00000000;  // 0.0

    coeff_imag_a[12][3] = 32'h00008000;  // 0.5j

    idx_a[12][3] = 4'd5;
    coeff_real_a[12][4] = 32'h00000000;  // 0.0

    coeff_imag_a[12][4] = 32'hFFFF8000;  // -0.5j

    idx_a[12][4] = 4'd6;
    coeff_real_a[12][5] = 32'h00000000;  // 0.0

    coeff_imag_a[12][5] = 32'h00008000;  // 0.5j

    idx_a[12][5] = 4'd9;
    coeff_real_a[12][6] = 32'h00000000;  // 0.0

    coeff_imag_a[12][6] = 32'hFFFF8000;  // -0.5j

    idx_a[12][6] = 4'd10;
    coeff_real_a[12][7] = 32'h00000000;  // 0.0

    coeff_imag_a[12][7] = 32'hFFFF8000;  // -0.5j

    idx_a[12][7] = 4'd13;

    // a13 computation

    coeff_real_a[13][0] = 32'h00010000;  // 1.0

    coeff_imag_a[13][0] = 32'h00000000;  // 0.0j

    idx_a[13][0] = 4'd0;
    coeff_real_a[13][1] = 32'h00000000;  // 0.0

    coeff_imag_a[13][1] = 32'hFFFF8000;  // -0.5j

    idx_a[13][1] = 4'd1;
    coeff_real_a[13][2] = 32'h00000000;  // 0.0

    coeff_imag_a[13][2] = 32'h00008000;  // 0.5j

    idx_a[13][2] = 4'd2;
    coeff_real_a[13][3] = 32'h00000000;  // 0.0

    coeff_imag_a[13][3] = 32'hFFFF8000;  // -0.5j

    idx_a[13][3] = 4'd5;
    coeff_real_a[13][4] = 32'h00000000;  // 0.0

    coeff_imag_a[13][4] = 32'h00008000;  // 0.5j

    idx_a[13][4] = 4'd6;
    coeff_real_a[13][5] = 32'h00000000;  // 0.0

    coeff_imag_a[13][5] = 32'hFFFF8000;  // -0.5j

    idx_a[13][5] = 4'd9;
    coeff_real_a[13][6] = 32'h00000000;  // 0.0

    coeff_imag_a[13][6] = 32'h00008000;  // 0.5j

    idx_a[13][6] = 4'd10;
    coeff_real_a[13][7] = 32'h00000000;  // 0.0

    coeff_imag_a[13][7] = 32'h00008000;  // 0.5j

    idx_a[13][7] = 4'd13;

    // a14 computation

    coeff_real_a[14][0] = 32'h00000000;  // 0.0

    coeff_imag_a[14][0] = 32'h00008000;  // 0.5j

    idx_a[14][0] = 4'd0;
    coeff_real_a[14][1] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[14][1] = 32'h00000000;  // 0.0j

    idx_a[14][1] = 4'd1;
    coeff_real_a[14][2] = 32'h00008000;  // 0.5

    coeff_imag_a[14][2] = 32'h00000000;  // 0.0j

    idx_a[14][2] = 4'd2;
    coeff_real_a[14][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[14][3] = 32'h00000000;  // 0.0j

    idx_a[14][3] = 4'd3;
    coeff_real_a[14][4] = 32'h00008000;  // 0.5

    coeff_imag_a[14][4] = 32'h00000000;  // 0.0j

    idx_a[14][4] = 4'd4;
    coeff_real_a[14][5] = 32'h00000000;  // 0.0

    coeff_imag_a[14][5] = 32'hFFFF8000;  // -0.5j

    idx_a[14][5] = 4'd5;
    coeff_real_a[14][6] = 32'h00000000;  // 0.0

    coeff_imag_a[14][6] = 32'h00008000;  // 0.5j

    idx_a[14][6] = 4'd6;
    coeff_real_a[14][7] = 32'h00000000;  // 0.0

    coeff_imag_a[14][7] = 32'h00008000;  // 0.5j

    idx_a[14][7] = 4'd7;

    // a15 computation

    coeff_real_a[15][0] = 32'h00010000;  // 1.0

    coeff_imag_a[15][0] = 32'h00000000;  // 0.0j

    idx_a[15][0] = 4'd0;
    coeff_real_a[15][1] = 32'h00000000;  // 0.0

    coeff_imag_a[15][1] = 32'h00008000;  // 0.5j

    idx_a[15][1] = 4'd2;
    coeff_real_a[15][2] = 32'h00000000;  // 0.0

    coeff_imag_a[15][2] = 32'h00008000;  // 0.5j

    idx_a[15][2] = 4'd3;
    coeff_real_a[15][3] = 32'h00000000;  // 0.0

    coeff_imag_a[15][3] = 32'hFFFF8000;  // -0.5j

    idx_a[15][3] = 4'd6;
    coeff_real_a[15][4] = 32'h00000000;  // 0.0

    coeff_imag_a[15][4] = 32'hFFFF8000;  // -0.5j

    idx_a[15][4] = 4'd7;
    coeff_real_a[15][5] = 32'h00000000;  // 0.0

    coeff_imag_a[15][5] = 32'hFFFF8000;  // -0.5j

    idx_a[15][5] = 4'd10;
    coeff_real_a[15][6] = 32'h00000000;  // 0.0

    coeff_imag_a[15][6] = 32'hFFFF8000;  // -0.5j

    idx_a[15][6] = 4'd11;
    coeff_real_a[15][7] = 32'h00000000;  // 0.0

    coeff_imag_a[15][7] = 32'hFFFF8000;  // -0.5j

    idx_a[15][7] = 4'd14;

    // a16 computation

    coeff_real_a[16][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[16][0] = 32'h00000000;  // 0.0j

    idx_a[16][0] = 4'd0;
    coeff_real_a[16][1] = 32'h00000000;  // 0.0

    coeff_imag_a[16][1] = 32'h00008000;  // 0.5j

    idx_a[16][1] = 4'd1;
    coeff_real_a[16][2] = 32'h00000000;  // 0.0

    coeff_imag_a[16][2] = 32'h00008000;  // 0.5j

    idx_a[16][2] = 4'd2;
    coeff_real_a[16][3] = 32'h00000000;  // 0.0

    coeff_imag_a[16][3] = 32'hFFFF8000;  // -0.5j

    idx_a[16][3] = 4'd3;
    coeff_real_a[16][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[16][4] = 32'h00000000;  // 0.0j

    idx_a[16][4] = 4'd4;
    coeff_real_a[16][5] = 32'h00000000;  // 0.0

    coeff_imag_a[16][5] = 32'hFFFF8000;  // -0.5j

    idx_a[16][5] = 4'd5;
    coeff_real_a[16][6] = 32'h00000000;  // 0.0

    coeff_imag_a[16][6] = 32'hFFFF8000;  // -0.5j

    idx_a[16][6] = 4'd6;
    coeff_real_a[16][7] = 32'h00000000;  // 0.0

    coeff_imag_a[16][7] = 32'hFFFF8000;  // -0.5j

    idx_a[16][7] = 4'd7;

    // a17 computation

    coeff_real_a[17][0] = 32'h00010000;  // 1.0

    coeff_imag_a[17][0] = 32'h00000000;  // 0.0j

    idx_a[17][0] = 4'd0;
    coeff_real_a[17][1] = 32'h00000000;  // 0.0

    coeff_imag_a[17][1] = 32'h00008000;  // 0.5j

    idx_a[17][1] = 4'd0;
    coeff_real_a[17][2] = 32'h00000000;  // 0.0

    coeff_imag_a[17][2] = 32'h00008000;  // 0.5j

    idx_a[17][2] = 4'd1;
    coeff_real_a[17][3] = 32'h00000000;  // 0.0

    coeff_imag_a[17][3] = 32'h00008000;  // 0.5j

    idx_a[17][3] = 4'd4;
    coeff_real_a[17][4] = 32'h00000000;  // 0.0

    coeff_imag_a[17][4] = 32'h00008000;  // 0.5j

    idx_a[17][4] = 4'd5;
    coeff_real_a[17][5] = 32'h00000000;  // 0.0

    coeff_imag_a[17][5] = 32'h00008000;  // 0.5j

    idx_a[17][5] = 4'd8;
    coeff_real_a[17][6] = 32'h00000000;  // 0.0

    coeff_imag_a[17][6] = 32'h00008000;  // 0.5j

    idx_a[17][6] = 4'd9;
    coeff_real_a[17][7] = 32'h00000000;  // 0.0

    coeff_imag_a[17][7] = 32'h00008000;  // 0.5j

    idx_a[17][7] = 4'd12;

    // a18 computation

    coeff_real_a[18][0] = 32'h00000000;  // 0.0

    coeff_imag_a[18][0] = 32'h00008000;  // 0.5j

    idx_a[18][0] = 4'd0;
    coeff_real_a[18][1] = 32'h00000000;  // 0.0

    coeff_imag_a[18][1] = 32'h00008000;  // 0.5j

    idx_a[18][1] = 4'd1;
    coeff_real_a[18][2] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[18][2] = 32'h00000000;  // 0.0j

    idx_a[18][2] = 4'd2;
    coeff_real_a[18][3] = 32'h00000000;  // 0.0

    coeff_imag_a[18][3] = 32'h00008000;  // 0.5j

    idx_a[18][3] = 4'd3;
    coeff_real_a[18][4] = 32'h00000000;  // 0.0

    coeff_imag_a[18][4] = 32'h00008000;  // 0.5j

    idx_a[18][4] = 4'd4;
    coeff_real_a[18][5] = 32'h00000000;  // 0.0

    coeff_imag_a[18][5] = 32'h00008000;  // 0.5j

    idx_a[18][5] = 4'd5;
    coeff_real_a[18][6] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[18][6] = 32'h00000000;  // 0.0j

    idx_a[18][6] = 4'd6;
    coeff_real_a[18][7] = 32'h00000000;  // 0.0

    coeff_imag_a[18][7] = 32'h00008000;  // 0.5j

    idx_a[18][7] = 4'd7;

    // a19 computation

    coeff_real_a[19][0] = 32'h00010000;  // 1.0

    coeff_imag_a[19][0] = 32'h00000000;  // 0.0j

    idx_a[19][0] = 4'd0;
    coeff_real_a[19][1] = 32'h00000000;  // 0.0

    coeff_imag_a[19][1] = 32'hFFFF8000;  // -0.5j

    idx_a[19][1] = 4'd2;
    coeff_real_a[19][2] = 32'h00000000;  // 0.0

    coeff_imag_a[19][2] = 32'h00008000;  // 0.5j

    idx_a[19][2] = 4'd3;
    coeff_real_a[19][3] = 32'h00000000;  // 0.0

    coeff_imag_a[19][3] = 32'hFFFF8000;  // -0.5j

    idx_a[19][3] = 4'd6;
    coeff_real_a[19][4] = 32'h00000000;  // 0.0

    coeff_imag_a[19][4] = 32'h00008000;  // 0.5j

    idx_a[19][4] = 4'd7;
    coeff_real_a[19][5] = 32'h00000000;  // 0.0

    coeff_imag_a[19][5] = 32'hFFFF8000;  // -0.5j

    idx_a[19][5] = 4'd10;
    coeff_real_a[19][6] = 32'h00000000;  // 0.0

    coeff_imag_a[19][6] = 32'h00008000;  // 0.5j

    idx_a[19][6] = 4'd11;
    coeff_real_a[19][7] = 32'h00000000;  // 0.0

    coeff_imag_a[19][7] = 32'h00008000;  // 0.5j

    idx_a[19][7] = 4'd14;

    // a20 computation

    coeff_real_a[20][0] = 32'h00010000;  // 1.0

    coeff_imag_a[20][0] = 32'h00000000;  // 0.0j

    idx_a[20][0] = 4'd0;
    coeff_real_a[20][1] = 32'h00000000;  // 0.0

    coeff_imag_a[20][1] = 32'h00008000;  // 0.5j

    idx_a[20][1] = 4'd1;
    coeff_real_a[20][2] = 32'h00000000;  // 0.0

    coeff_imag_a[20][2] = 32'hFFFF8000;  // -0.5j

    idx_a[20][2] = 4'd2;
    coeff_real_a[20][3] = 32'h00000000;  // 0.0

    coeff_imag_a[20][3] = 32'h00008000;  // 0.5j

    idx_a[20][3] = 4'd5;
    coeff_real_a[20][4] = 32'h00000000;  // 0.0

    coeff_imag_a[20][4] = 32'hFFFF8000;  // -0.5j

    idx_a[20][4] = 4'd6;
    coeff_real_a[20][5] = 32'h00000000;  // 0.0

    coeff_imag_a[20][5] = 32'hFFFF8000;  // -0.5j

    idx_a[20][5] = 4'd9;
    coeff_real_a[20][6] = 32'h00000000;  // 0.0

    coeff_imag_a[20][6] = 32'h00008000;  // 0.5j

    idx_a[20][6] = 4'd10;
    coeff_real_a[20][7] = 32'h00000000;  // 0.0

    coeff_imag_a[20][7] = 32'hFFFF8000;  // -0.5j

    idx_a[20][7] = 4'd13;

    // a21 computation

    coeff_real_a[21][0] = 32'h00000000;  // 0.0

    coeff_imag_a[21][0] = 32'h00008000;  // 0.5j

    idx_a[21][0] = 4'd0;
    coeff_real_a[21][1] = 32'h00000000;  // 0.0

    coeff_imag_a[21][1] = 32'hFFFF8000;  // -0.5j

    idx_a[21][1] = 4'd1;
    coeff_real_a[21][2] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[21][2] = 32'h00000000;  // 0.0j

    idx_a[21][2] = 4'd2;
    coeff_real_a[21][3] = 32'h00000000;  // 0.0

    coeff_imag_a[21][3] = 32'hFFFF8000;  // -0.5j

    idx_a[21][3] = 4'd3;
    coeff_real_a[21][4] = 32'h00000000;  // 0.0

    coeff_imag_a[21][4] = 32'hFFFF8000;  // -0.5j

    idx_a[21][4] = 4'd4;
    coeff_real_a[21][5] = 32'h00000000;  // 0.0

    coeff_imag_a[21][5] = 32'h00008000;  // 0.5j

    idx_a[21][5] = 4'd5;
    coeff_real_a[21][6] = 32'h00008000;  // 0.5

    coeff_imag_a[21][6] = 32'h00000000;  // 0.0j

    idx_a[21][6] = 4'd6;
    coeff_real_a[21][7] = 32'h00000000;  // 0.0

    coeff_imag_a[21][7] = 32'h00008000;  // 0.5j

    idx_a[21][7] = 4'd7;

    // a22 computation

    coeff_real_a[22][0] = 32'h00010000;  // 1.0

    coeff_imag_a[22][0] = 32'h00000000;  // 0.0j

    idx_a[22][0] = 4'd0;
    coeff_real_a[22][1] = 32'h00000000;  // 0.0

    coeff_imag_a[22][1] = 32'hFFFF8000;  // -0.5j

    idx_a[22][1] = 4'd0;
    coeff_real_a[22][2] = 32'h00000000;  // 0.0

    coeff_imag_a[22][2] = 32'h00008000;  // 0.5j

    idx_a[22][2] = 4'd3;
    coeff_real_a[22][3] = 32'h00000000;  // 0.0

    coeff_imag_a[22][3] = 32'hFFFF8000;  // -0.5j

    idx_a[22][3] = 4'd4;
    coeff_real_a[22][4] = 32'h00000000;  // 0.0

    coeff_imag_a[22][4] = 32'hFFFF8000;  // -0.5j

    idx_a[22][4] = 4'd7;
    coeff_real_a[22][5] = 32'h00000000;  // 0.0

    coeff_imag_a[22][5] = 32'hFFFF8000;  // -0.5j

    idx_a[22][5] = 4'd8;
    coeff_real_a[22][6] = 32'h00000000;  // 0.0

    coeff_imag_a[22][6] = 32'hFFFF8000;  // -0.5j

    idx_a[22][6] = 4'd11;
    coeff_real_a[22][7] = 32'h00000000;  // 0.0

    coeff_imag_a[22][7] = 32'h00008000;  // 0.5j

    idx_a[22][7] = 4'd12;

    // a23 computation

    coeff_real_a[23][0] = 32'h00010000;  // 1.0

    coeff_imag_a[23][0] = 32'h00000000;  // 0.0j

    idx_a[23][0] = 4'd0;
    coeff_real_a[23][1] = 32'h00000000;  // 0.0

    coeff_imag_a[23][1] = 32'hFFFF8000;  // -0.5j

    idx_a[23][1] = 4'd2;
    coeff_real_a[23][2] = 32'h00000000;  // 0.0

    coeff_imag_a[23][2] = 32'hFFFF8000;  // -0.5j

    idx_a[23][2] = 4'd3;
    coeff_real_a[23][3] = 32'h00000000;  // 0.0

    coeff_imag_a[23][3] = 32'hFFFF8000;  // -0.5j

    idx_a[23][3] = 4'd6;
    coeff_real_a[23][4] = 32'h00000000;  // 0.0

    coeff_imag_a[23][4] = 32'h00008000;  // 0.5j

    idx_a[23][4] = 4'd7;
    coeff_real_a[23][5] = 32'h00000000;  // 0.0

    coeff_imag_a[23][5] = 32'hFFFF8000;  // -0.5j

    idx_a[23][5] = 4'd10;
    coeff_real_a[23][6] = 32'h00000000;  // 0.0

    coeff_imag_a[23][6] = 32'h00008000;  // 0.5j

    idx_a[23][6] = 4'd11;
    coeff_real_a[23][7] = 32'h00000000;  // 0.0

    coeff_imag_a[23][7] = 32'h00008000;  // 0.5j

    idx_a[23][7] = 4'd14;

    // a24 computation

    coeff_real_a[24][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[24][0] = 32'h00000000;  // 0.0j

    idx_a[24][0] = 4'd0;
    coeff_real_a[24][1] = 32'h00008000;  // 0.5

    coeff_imag_a[24][1] = 32'h00000000;  // 0.0j

    idx_a[24][1] = 4'd1;
    coeff_real_a[24][2] = 32'h00000000;  // 0.0

    coeff_imag_a[24][2] = 32'hFFFF8000;  // -0.5j

    idx_a[24][2] = 4'd2;
    coeff_real_a[24][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[24][3] = 32'h00000000;  // 0.0j

    idx_a[24][3] = 4'd3;
    coeff_real_a[24][4] = 32'h00000000;  // 0.0

    coeff_imag_a[24][4] = 32'hFFFF8000;  // -0.5j

    idx_a[24][4] = 4'd4;
    coeff_real_a[24][5] = 32'h00000000;  // 0.0

    coeff_imag_a[24][5] = 32'h00008000;  // 0.5j

    idx_a[24][5] = 4'd5;
    coeff_real_a[24][6] = 32'h00008000;  // 0.5

    coeff_imag_a[24][6] = 32'h00000000;  // 0.0j

    idx_a[24][6] = 4'd6;
    coeff_real_a[24][7] = 32'h00000000;  // 0.0

    coeff_imag_a[24][7] = 32'hFFFF8000;  // -0.5j

    idx_a[24][7] = 4'd7;

    // a25 computation

    coeff_real_a[25][0] = 32'h00010000;  // 1.0

    coeff_imag_a[25][0] = 32'h00000000;  // 0.0j

    idx_a[25][0] = 4'd0;
    coeff_real_a[25][1] = 32'h00000000;  // 0.0

    coeff_imag_a[25][1] = 32'hFFFF8000;  // -0.5j

    idx_a[25][1] = 4'd2;
    coeff_real_a[25][2] = 32'h00000000;  // 0.0

    coeff_imag_a[25][2] = 32'h00008000;  // 0.5j

    idx_a[25][2] = 4'd3;
    coeff_real_a[25][3] = 32'h00000000;  // 0.0

    coeff_imag_a[25][3] = 32'hFFFF8000;  // -0.5j

    idx_a[25][3] = 4'd6;
    coeff_real_a[25][4] = 32'h00000000;  // 0.0

    coeff_imag_a[25][4] = 32'hFFFF8000;  // -0.5j

    idx_a[25][4] = 4'd7;
    coeff_real_a[25][5] = 32'h00000000;  // 0.0

    coeff_imag_a[25][5] = 32'h00008000;  // 0.5j

    idx_a[25][5] = 4'd10;
    coeff_real_a[25][6] = 32'h00000000;  // 0.0

    coeff_imag_a[25][6] = 32'h00008000;  // 0.5j

    idx_a[25][6] = 4'd11;
    coeff_real_a[25][7] = 32'h00000000;  // 0.0

    coeff_imag_a[25][7] = 32'h00008000;  // 0.5j

    idx_a[25][7] = 4'd14;

    // a26 computation

    coeff_real_a[26][0] = 32'h00010000;  // 1.0

    coeff_imag_a[26][0] = 32'h00000000;  // 0.0j

    idx_a[26][0] = 4'd0;
    coeff_real_a[26][1] = 32'h00000000;  // 0.0

    coeff_imag_a[26][1] = 32'h00008000;  // 0.5j

    idx_a[26][1] = 4'd1;
    coeff_real_a[26][2] = 32'h00000000;  // 0.0

    coeff_imag_a[26][2] = 32'h00008000;  // 0.5j

    idx_a[26][2] = 4'd2;
    coeff_real_a[26][3] = 32'h00000000;  // 0.0

    coeff_imag_a[26][3] = 32'hFFFF8000;  // -0.5j

    idx_a[26][3] = 4'd5;
    coeff_real_a[26][4] = 32'h00000000;  // 0.0

    coeff_imag_a[26][4] = 32'hFFFF8000;  // -0.5j

    idx_a[26][4] = 4'd6;
    coeff_real_a[26][5] = 32'h00000000;  // 0.0

    coeff_imag_a[26][5] = 32'h00008000;  // 0.5j

    idx_a[26][5] = 4'd9;
    coeff_real_a[26][6] = 32'h00000000;  // 0.0

    coeff_imag_a[26][6] = 32'h00008000;  // 0.5j

    idx_a[26][6] = 4'd10;
    coeff_real_a[26][7] = 32'h00000000;  // 0.0

    coeff_imag_a[26][7] = 32'hFFFF8000;  // -0.5j

    idx_a[26][7] = 4'd13;

    // a27 computation

    coeff_real_a[27][0] = 32'h00000000;  // 0.0

    coeff_imag_a[27][0] = 32'hFFFF8000;  // -0.5j

    idx_a[27][0] = 4'd0;
    coeff_real_a[27][1] = 32'h00000000;  // 0.0

    coeff_imag_a[27][1] = 32'hFFFF8000;  // -0.5j

    idx_a[27][1] = 4'd1;
    coeff_real_a[27][2] = 32'h00008000;  // 0.5

    coeff_imag_a[27][2] = 32'h00000000;  // 0.0j

    idx_a[27][2] = 4'd2;
    coeff_real_a[27][3] = 32'h00000000;  // 0.0

    coeff_imag_a[27][3] = 32'h00008000;  // 0.5j

    idx_a[27][3] = 4'd3;
    coeff_real_a[27][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[27][4] = 32'h00000000;  // 0.0j

    idx_a[27][4] = 4'd4;
    coeff_real_a[27][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[27][5] = 32'h00000000;  // 0.0j

    idx_a[27][5] = 4'd5;
    coeff_real_a[27][6] = 32'h00000000;  // 0.0

    coeff_imag_a[27][6] = 32'hFFFF8000;  // -0.5j

    idx_a[27][6] = 4'd6;
    coeff_real_a[27][7] = 32'h00008000;  // 0.5

    coeff_imag_a[27][7] = 32'h00000000;  // 0.0j

    idx_a[27][7] = 4'd7;

    // a28 computation

    coeff_real_a[28][0] = 32'h00010000;  // 1.0

    coeff_imag_a[28][0] = 32'h00000000;  // 0.0j

    idx_a[28][0] = 4'd0;
    coeff_real_a[28][1] = 32'h00000000;  // 0.0

    coeff_imag_a[28][1] = 32'h00008000;  // 0.5j

    idx_a[28][1] = 4'd0;
    coeff_real_a[28][2] = 32'h00000000;  // 0.0

    coeff_imag_a[28][2] = 32'h00008000;  // 0.5j

    idx_a[28][2] = 4'd1;
    coeff_real_a[28][3] = 32'h00000000;  // 0.0

    coeff_imag_a[28][3] = 32'hFFFF8000;  // -0.5j

    idx_a[28][3] = 4'd4;
    coeff_real_a[28][4] = 32'h00000000;  // 0.0

    coeff_imag_a[28][4] = 32'hFFFF8000;  // -0.5j

    idx_a[28][4] = 4'd5;
    coeff_real_a[28][5] = 32'h00000000;  // 0.0

    coeff_imag_a[28][5] = 32'h00008000;  // 0.5j

    idx_a[28][5] = 4'd8;
    coeff_real_a[28][6] = 32'h00000000;  // 0.0

    coeff_imag_a[28][6] = 32'h00008000;  // 0.5j

    idx_a[28][6] = 4'd9;
    coeff_real_a[28][7] = 32'h00000000;  // 0.0

    coeff_imag_a[28][7] = 32'hFFFF8000;  // -0.5j

    idx_a[28][7] = 4'd12;

    // a29 computation

    coeff_real_a[29][0] = 32'h00010000;  // 1.0

    coeff_imag_a[29][0] = 32'h00000000;  // 0.0j

    idx_a[29][0] = 4'd0;
    coeff_real_a[29][1] = 32'h00000000;  // 0.0

    coeff_imag_a[29][1] = 32'h00008000;  // 0.5j

    idx_a[29][1] = 4'd0;
    coeff_real_a[29][2] = 32'h00000000;  // 0.0

    coeff_imag_a[29][2] = 32'hFFFF8000;  // -0.5j

    idx_a[29][2] = 4'd3;
    coeff_real_a[29][3] = 32'h00000000;  // 0.0

    coeff_imag_a[29][3] = 32'hFFFF8000;  // -0.5j

    idx_a[29][3] = 4'd4;
    coeff_real_a[29][4] = 32'h00000000;  // 0.0

    coeff_imag_a[29][4] = 32'h00008000;  // 0.5j

    idx_a[29][4] = 4'd7;
    coeff_real_a[29][5] = 32'h00000000;  // 0.0

    coeff_imag_a[29][5] = 32'h00008000;  // 0.5j

    idx_a[29][5] = 4'd8;
    coeff_real_a[29][6] = 32'h00000000;  // 0.0

    coeff_imag_a[29][6] = 32'hFFFF8000;  // -0.5j

    idx_a[29][6] = 4'd11;
    coeff_real_a[29][7] = 32'h00000000;  // 0.0

    coeff_imag_a[29][7] = 32'hFFFF8000;  // -0.5j

    idx_a[29][7] = 4'd12;

    // a30 computation

    coeff_real_a[30][0] = 32'h00010000;  // 1.0

    coeff_imag_a[30][0] = 32'h00000000;  // 0.0j

    idx_a[30][0] = 4'd0;
    coeff_real_a[30][1] = 32'h00000000;  // 0.0

    coeff_imag_a[30][1] = 32'h00008000;  // 0.5j

    idx_a[30][1] = 4'd1;
    coeff_real_a[30][2] = 32'h00000000;  // 0.0

    coeff_imag_a[30][2] = 32'h00008000;  // 0.5j

    idx_a[30][2] = 4'd2;
    coeff_real_a[30][3] = 32'h00000000;  // 0.0

    coeff_imag_a[30][3] = 32'hFFFF8000;  // -0.5j

    idx_a[30][3] = 4'd5;
    coeff_real_a[30][4] = 32'h00000000;  // 0.0

    coeff_imag_a[30][4] = 32'hFFFF8000;  // -0.5j

    idx_a[30][4] = 4'd6;
    coeff_real_a[30][5] = 32'h00000000;  // 0.0

    coeff_imag_a[30][5] = 32'hFFFF8000;  // -0.5j

    idx_a[30][5] = 4'd9;
    coeff_real_a[30][6] = 32'h00000000;  // 0.0

    coeff_imag_a[30][6] = 32'hFFFF8000;  // -0.5j

    idx_a[30][6] = 4'd10;
    coeff_real_a[30][7] = 32'h00000000;  // 0.0

    coeff_imag_a[30][7] = 32'h00008000;  // 0.5j

    idx_a[30][7] = 4'd13;

    // a31 computation

    coeff_real_a[31][0] = 32'h00008000;  // 0.5

    coeff_imag_a[31][0] = 32'h00000000;  // 0.0j

    idx_a[31][0] = 4'd0;
    coeff_real_a[31][1] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[31][1] = 32'h00000000;  // 0.0j

    idx_a[31][1] = 4'd1;
    coeff_real_a[31][2] = 32'h00000000;  // 0.0

    coeff_imag_a[31][2] = 32'hFFFF8000;  // -0.5j

    idx_a[31][2] = 4'd2;
    coeff_real_a[31][3] = 32'h00008000;  // 0.5

    coeff_imag_a[31][3] = 32'h00000000;  // 0.0j

    idx_a[31][3] = 4'd3;
    coeff_real_a[31][4] = 32'h00008000;  // 0.5

    coeff_imag_a[31][4] = 32'h00000000;  // 0.0j

    idx_a[31][4] = 4'd4;
    coeff_real_a[31][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[31][5] = 32'h00000000;  // 0.0j

    idx_a[31][5] = 4'd5;
    coeff_real_a[31][6] = 32'h00000000;  // 0.0

    coeff_imag_a[31][6] = 32'hFFFF8000;  // -0.5j

    idx_a[31][6] = 4'd6;
    coeff_real_a[31][7] = 32'h00008000;  // 0.5

    coeff_imag_a[31][7] = 32'h00000000;  // 0.0j

    idx_a[31][7] = 4'd7;

    // a32 computation

    coeff_real_a[32][0] = 32'h00010000;  // 1.0

    coeff_imag_a[32][0] = 32'h00000000;  // 0.0j

    idx_a[32][0] = 4'd0;
    coeff_real_a[32][1] = 32'h00000000;  // 0.0

    coeff_imag_a[32][1] = 32'h00008000;  // 0.5j

    idx_a[32][1] = 4'd2;
    coeff_real_a[32][2] = 32'h00000000;  // 0.0

    coeff_imag_a[32][2] = 32'hFFFF8000;  // -0.5j

    idx_a[32][2] = 4'd3;
    coeff_real_a[32][3] = 32'h00000000;  // 0.0

    coeff_imag_a[32][3] = 32'h00008000;  // 0.5j

    idx_a[32][3] = 4'd6;
    coeff_real_a[32][4] = 32'h00000000;  // 0.0

    coeff_imag_a[32][4] = 32'h00008000;  // 0.5j

    idx_a[32][4] = 4'd7;
    coeff_real_a[32][5] = 32'h00000000;  // 0.0

    coeff_imag_a[32][5] = 32'hFFFF8000;  // -0.5j

    idx_a[32][5] = 4'd10;
    coeff_real_a[32][6] = 32'h00000000;  // 0.0

    coeff_imag_a[32][6] = 32'hFFFF8000;  // -0.5j

    idx_a[32][6] = 4'd11;
    coeff_real_a[32][7] = 32'h00000000;  // 0.0

    coeff_imag_a[32][7] = 32'h00008000;  // 0.5j

    idx_a[32][7] = 4'd14;

    // a33 computation

    coeff_real_a[33][0] = 32'h00008000;  // 0.5

    coeff_imag_a[33][0] = 32'h00000000;  // 0.0j

    idx_a[33][0] = 4'd0;
    coeff_real_a[33][1] = 32'h00000000;  // 0.0

    coeff_imag_a[33][1] = 32'h00008000;  // 0.5j

    idx_a[33][1] = 4'd1;
    coeff_real_a[33][2] = 32'h00000000;  // 0.0

    coeff_imag_a[33][2] = 32'hFFFF8000;  // -0.5j

    idx_a[33][2] = 4'd2;
    coeff_real_a[33][3] = 32'h00000000;  // 0.0

    coeff_imag_a[33][3] = 32'hFFFF8000;  // -0.5j

    idx_a[33][3] = 4'd3;
    coeff_real_a[33][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[33][4] = 32'h00000000;  // 0.0j

    idx_a[33][4] = 4'd4;
    coeff_real_a[33][5] = 32'h00000000;  // 0.0

    coeff_imag_a[33][5] = 32'h00008000;  // 0.5j

    idx_a[33][5] = 4'd5;
    coeff_real_a[33][6] = 32'h00000000;  // 0.0

    coeff_imag_a[33][6] = 32'hFFFF8000;  // -0.5j

    idx_a[33][6] = 4'd6;
    coeff_real_a[33][7] = 32'h00000000;  // 0.0

    coeff_imag_a[33][7] = 32'h00008000;  // 0.5j

    idx_a[33][7] = 4'd7;

    // a34 computation

    coeff_real_a[34][0] = 32'h00000000;  // 0.0

    coeff_imag_a[34][0] = 32'hFFFF8000;  // -0.5j

    idx_a[34][0] = 4'd0;
    coeff_real_a[34][1] = 32'h00000000;  // 0.0

    coeff_imag_a[34][1] = 32'h00008000;  // 0.5j

    idx_a[34][1] = 4'd1;
    coeff_real_a[34][2] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[34][2] = 32'h00000000;  // 0.0j

    idx_a[34][2] = 4'd2;
    coeff_real_a[34][3] = 32'h00000000;  // 0.0

    coeff_imag_a[34][3] = 32'h00008000;  // 0.5j

    idx_a[34][3] = 4'd3;
    coeff_real_a[34][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[34][4] = 32'h00000000;  // 0.0j

    idx_a[34][4] = 4'd4;
    coeff_real_a[34][5] = 32'h00008000;  // 0.5

    coeff_imag_a[34][5] = 32'h00000000;  // 0.0j

    idx_a[34][5] = 4'd5;
    coeff_real_a[34][6] = 32'h00000000;  // 0.0

    coeff_imag_a[34][6] = 32'h00008000;  // 0.5j

    idx_a[34][6] = 4'd6;
    coeff_real_a[34][7] = 32'h00008000;  // 0.5

    coeff_imag_a[34][7] = 32'h00000000;  // 0.0j

    idx_a[34][7] = 4'd7;

    // a35 computation

    coeff_real_a[35][0] = 32'h00010000;  // 1.0

    coeff_imag_a[35][0] = 32'h00000000;  // 0.0j

    idx_a[35][0] = 4'd0;
    coeff_real_a[35][1] = 32'h00000000;  // 0.0

    coeff_imag_a[35][1] = 32'hFFFF8000;  // -0.5j

    idx_a[35][1] = 4'd2;
    coeff_real_a[35][2] = 32'h00000000;  // 0.0

    coeff_imag_a[35][2] = 32'h00008000;  // 0.5j

    idx_a[35][2] = 4'd3;
    coeff_real_a[35][3] = 32'h00000000;  // 0.0

    coeff_imag_a[35][3] = 32'h00008000;  // 0.5j

    idx_a[35][3] = 4'd6;
    coeff_real_a[35][4] = 32'h00000000;  // 0.0

    coeff_imag_a[35][4] = 32'hFFFF8000;  // -0.5j

    idx_a[35][4] = 4'd7;
    coeff_real_a[35][5] = 32'h00000000;  // 0.0

    coeff_imag_a[35][5] = 32'hFFFF8000;  // -0.5j

    idx_a[35][5] = 4'd10;
    coeff_real_a[35][6] = 32'h00000000;  // 0.0

    coeff_imag_a[35][6] = 32'h00008000;  // 0.5j

    idx_a[35][6] = 4'd11;
    coeff_real_a[35][7] = 32'h00000000;  // 0.0

    coeff_imag_a[35][7] = 32'hFFFF8000;  // -0.5j

    idx_a[35][7] = 4'd14;

    // a36 computation

    coeff_real_a[36][0] = 32'h00010000;  // 1.0

    coeff_imag_a[36][0] = 32'h00000000;  // 0.0j

    idx_a[36][0] = 4'd0;
    coeff_real_a[36][1] = 32'h00000000;  // 0.0

    coeff_imag_a[36][1] = 32'hFFFF8000;  // -0.5j

    idx_a[36][1] = 4'd1;
    coeff_real_a[36][2] = 32'h00000000;  // 0.0

    coeff_imag_a[36][2] = 32'hFFFF8000;  // -0.5j

    idx_a[36][2] = 4'd2;
    coeff_real_a[36][3] = 32'h00000000;  // 0.0

    coeff_imag_a[36][3] = 32'h00008000;  // 0.5j

    idx_a[36][3] = 4'd5;
    coeff_real_a[36][4] = 32'h00000000;  // 0.0

    coeff_imag_a[36][4] = 32'h00008000;  // 0.5j

    idx_a[36][4] = 4'd6;
    coeff_real_a[36][5] = 32'h00000000;  // 0.0

    coeff_imag_a[36][5] = 32'hFFFF8000;  // -0.5j

    idx_a[36][5] = 4'd9;
    coeff_real_a[36][6] = 32'h00000000;  // 0.0

    coeff_imag_a[36][6] = 32'hFFFF8000;  // -0.5j

    idx_a[36][6] = 4'd10;
    coeff_real_a[36][7] = 32'h00000000;  // 0.0

    coeff_imag_a[36][7] = 32'hFFFF8000;  // -0.5j

    idx_a[36][7] = 4'd13;

    // a37 computation

    coeff_real_a[37][0] = 32'h00008000;  // 0.5

    coeff_imag_a[37][0] = 32'h00000000;  // 0.0j

    idx_a[37][0] = 4'd0;
    coeff_real_a[37][1] = 32'h00000000;  // 0.0

    coeff_imag_a[37][1] = 32'hFFFF8000;  // -0.5j

    idx_a[37][1] = 4'd1;
    coeff_real_a[37][2] = 32'h00000000;  // 0.0

    coeff_imag_a[37][2] = 32'hFFFF8000;  // -0.5j

    idx_a[37][2] = 4'd2;
    coeff_real_a[37][3] = 32'h00000000;  // 0.0

    coeff_imag_a[37][3] = 32'hFFFF8000;  // -0.5j

    idx_a[37][3] = 4'd3;
    coeff_real_a[37][4] = 32'h00000000;  // 0.0

    coeff_imag_a[37][4] = 32'h00008000;  // 0.5j

    idx_a[37][4] = 4'd4;
    coeff_real_a[37][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[37][5] = 32'h00000000;  // 0.0j

    idx_a[37][5] = 4'd5;
    coeff_real_a[37][6] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[37][6] = 32'h00000000;  // 0.0j

    idx_a[37][6] = 4'd6;
    coeff_real_a[37][7] = 32'h00008000;  // 0.5

    coeff_imag_a[37][7] = 32'h00000000;  // 0.0j

    idx_a[37][7] = 4'd7;

    // a38 computation

    coeff_real_a[38][0] = 32'h00010000;  // 1.0

    coeff_imag_a[38][0] = 32'h00000000;  // 0.0j

    idx_a[38][0] = 4'd0;
    coeff_real_a[38][1] = 32'h00000000;  // 0.0

    coeff_imag_a[38][1] = 32'hFFFF8000;  // -0.5j

    idx_a[38][1] = 4'd1;
    coeff_real_a[38][2] = 32'h00000000;  // 0.0

    coeff_imag_a[38][2] = 32'hFFFF8000;  // -0.5j

    idx_a[38][2] = 4'd2;
    coeff_real_a[38][3] = 32'h00000000;  // 0.0

    coeff_imag_a[38][3] = 32'hFFFF8000;  // -0.5j

    idx_a[38][3] = 4'd5;
    coeff_real_a[38][4] = 32'h00000000;  // 0.0

    coeff_imag_a[38][4] = 32'hFFFF8000;  // -0.5j

    idx_a[38][4] = 4'd6;
    coeff_real_a[38][5] = 32'h00000000;  // 0.0

    coeff_imag_a[38][5] = 32'hFFFF8000;  // -0.5j

    idx_a[38][5] = 4'd9;
    coeff_real_a[38][6] = 32'h00000000;  // 0.0

    coeff_imag_a[38][6] = 32'hFFFF8000;  // -0.5j

    idx_a[38][6] = 4'd10;
    coeff_real_a[38][7] = 32'h00000000;  // 0.0

    coeff_imag_a[38][7] = 32'hFFFF8000;  // -0.5j

    idx_a[38][7] = 4'd13;

    // a39 computation

    coeff_real_a[39][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[39][0] = 32'h00000000;  // 0.0j

    idx_a[39][0] = 4'd0;
    coeff_real_a[39][1] = 32'h00000000;  // 0.0

    coeff_imag_a[39][1] = 32'hFFFF8000;  // -0.5j

    idx_a[39][1] = 4'd1;
    coeff_real_a[39][2] = 32'h00000000;  // 0.0

    coeff_imag_a[39][2] = 32'hFFFF8000;  // -0.5j

    idx_a[39][2] = 4'd2;
    coeff_real_a[39][3] = 32'h00000000;  // 0.0

    coeff_imag_a[39][3] = 32'hFFFF8000;  // -0.5j

    idx_a[39][3] = 4'd3;
    coeff_real_a[39][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[39][4] = 32'h00000000;  // 0.0j

    idx_a[39][4] = 4'd4;
    coeff_real_a[39][5] = 32'h00000000;  // 0.0

    coeff_imag_a[39][5] = 32'h00008000;  // 0.5j

    idx_a[39][5] = 4'd5;
    coeff_real_a[39][6] = 32'h00000000;  // 0.0

    coeff_imag_a[39][6] = 32'h00008000;  // 0.5j

    idx_a[39][6] = 4'd6;
    coeff_real_a[39][7] = 32'h00000000;  // 0.0

    coeff_imag_a[39][7] = 32'hFFFF8000;  // -0.5j

    idx_a[39][7] = 4'd7;

    // a40 computation

    coeff_real_a[40][0] = 32'h00010000;  // 1.0

    coeff_imag_a[40][0] = 32'h00000000;  // 0.0j

    idx_a[40][0] = 4'd0;
    coeff_real_a[40][1] = 32'h00000000;  // 0.0

    coeff_imag_a[40][1] = 32'hFFFF8000;  // -0.5j

    idx_a[40][1] = 4'd0;
    coeff_real_a[40][2] = 32'h00000000;  // 0.0

    coeff_imag_a[40][2] = 32'hFFFF8000;  // -0.5j

    idx_a[40][2] = 4'd1;
    coeff_real_a[40][3] = 32'h00000000;  // 0.0

    coeff_imag_a[40][3] = 32'h00008000;  // 0.5j

    idx_a[40][3] = 4'd4;
    coeff_real_a[40][4] = 32'h00000000;  // 0.0

    coeff_imag_a[40][4] = 32'h00008000;  // 0.5j

    idx_a[40][4] = 4'd5;
    coeff_real_a[40][5] = 32'h00000000;  // 0.0

    coeff_imag_a[40][5] = 32'hFFFF8000;  // -0.5j

    idx_a[40][5] = 4'd8;
    coeff_real_a[40][6] = 32'h00000000;  // 0.0

    coeff_imag_a[40][6] = 32'hFFFF8000;  // -0.5j

    idx_a[40][6] = 4'd9;
    coeff_real_a[40][7] = 32'h00000000;  // 0.0

    coeff_imag_a[40][7] = 32'h00008000;  // 0.5j

    idx_a[40][7] = 4'd12;

    // a41 computation

    coeff_real_a[41][0] = 32'h00010000;  // 1.0

    coeff_imag_a[41][0] = 32'h00000000;  // 0.0j

    idx_a[41][0] = 4'd0;
    coeff_real_a[41][1] = 32'h00000000;  // 0.0

    coeff_imag_a[41][1] = 32'hFFFF8000;  // -0.5j

    idx_a[41][1] = 4'd0;
    coeff_real_a[41][2] = 32'h00000000;  // 0.0

    coeff_imag_a[41][2] = 32'hFFFF8000;  // -0.5j

    idx_a[41][2] = 4'd3;
    coeff_real_a[41][3] = 32'h00000000;  // 0.0

    coeff_imag_a[41][3] = 32'h00008000;  // 0.5j

    idx_a[41][3] = 4'd4;
    coeff_real_a[41][4] = 32'h00000000;  // 0.0

    coeff_imag_a[41][4] = 32'h00008000;  // 0.5j

    idx_a[41][4] = 4'd7;
    coeff_real_a[41][5] = 32'h00000000;  // 0.0

    coeff_imag_a[41][5] = 32'h00008000;  // 0.5j

    idx_a[41][5] = 4'd8;
    coeff_real_a[41][6] = 32'h00000000;  // 0.0

    coeff_imag_a[41][6] = 32'h00008000;  // 0.5j

    idx_a[41][6] = 4'd11;
    coeff_real_a[41][7] = 32'h00000000;  // 0.0

    coeff_imag_a[41][7] = 32'h00008000;  // 0.5j

    idx_a[41][7] = 4'd12;

    // a42 computation

    coeff_real_a[42][0] = 32'h00010000;  // 1.0

    coeff_imag_a[42][0] = 32'h00000000;  // 0.0j

    idx_a[42][0] = 4'd0;
    coeff_real_a[42][1] = 32'h00000000;  // 0.0

    coeff_imag_a[42][1] = 32'h00008000;  // 0.5j

    idx_a[42][1] = 4'd0;
    coeff_real_a[42][2] = 32'h00000000;  // 0.0

    coeff_imag_a[42][2] = 32'h00008000;  // 0.5j

    idx_a[42][2] = 4'd3;
    coeff_real_a[42][3] = 32'h00000000;  // 0.0

    coeff_imag_a[42][3] = 32'hFFFF8000;  // -0.5j

    idx_a[42][3] = 4'd4;
    coeff_real_a[42][4] = 32'h00000000;  // 0.0

    coeff_imag_a[42][4] = 32'h00008000;  // 0.5j

    idx_a[42][4] = 4'd7;
    coeff_real_a[42][5] = 32'h00000000;  // 0.0

    coeff_imag_a[42][5] = 32'hFFFF8000;  // -0.5j

    idx_a[42][5] = 4'd8;
    coeff_real_a[42][6] = 32'h00000000;  // 0.0

    coeff_imag_a[42][6] = 32'h00008000;  // 0.5j

    idx_a[42][6] = 4'd11;
    coeff_real_a[42][7] = 32'h00000000;  // 0.0

    coeff_imag_a[42][7] = 32'hFFFF8000;  // -0.5j

    idx_a[42][7] = 4'd12;

    // a43 computation

    coeff_real_a[43][0] = 32'h00000000;  // 0.0

    coeff_imag_a[43][0] = 32'h00008000;  // 0.5j

    idx_a[43][0] = 4'd0;
    coeff_real_a[43][1] = 32'h00008000;  // 0.5

    coeff_imag_a[43][1] = 32'h00000000;  // 0.0j

    idx_a[43][1] = 4'd1;
    coeff_real_a[43][2] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[43][2] = 32'h00000000;  // 0.0j

    idx_a[43][2] = 4'd2;
    coeff_real_a[43][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_a[43][3] = 32'h00000000;  // 0.0j

    idx_a[43][3] = 4'd3;
    coeff_real_a[43][4] = 32'h00008000;  // 0.5

    coeff_imag_a[43][4] = 32'h00000000;  // 0.0j

    idx_a[43][4] = 4'd4;
    coeff_real_a[43][5] = 32'h00000000;  // 0.0

    coeff_imag_a[43][5] = 32'h00008000;  // 0.5j

    idx_a[43][5] = 4'd5;
    coeff_real_a[43][6] = 32'h00000000;  // 0.0

    coeff_imag_a[43][6] = 32'hFFFF8000;  // -0.5j

    idx_a[43][6] = 4'd6;
    coeff_real_a[43][7] = 32'h00000000;  // 0.0

    coeff_imag_a[43][7] = 32'h00008000;  // 0.5j

    idx_a[43][7] = 4'd7;

    // a44 computation

    coeff_real_a[44][0] = 32'h00010000;  // 1.0

    coeff_imag_a[44][0] = 32'h00000000;  // 0.0j

    idx_a[44][0] = 4'd0;
    coeff_real_a[44][1] = 32'h00000000;  // 0.0

    coeff_imag_a[44][1] = 32'hFFFF8000;  // -0.5j

    idx_a[44][1] = 4'd2;
    coeff_real_a[44][2] = 32'h00000000;  // 0.0

    coeff_imag_a[44][2] = 32'hFFFF8000;  // -0.5j

    idx_a[44][2] = 4'd3;
    coeff_real_a[44][3] = 32'h00000000;  // 0.0

    coeff_imag_a[44][3] = 32'hFFFF8000;  // -0.5j

    idx_a[44][3] = 4'd6;
    coeff_real_a[44][4] = 32'h00000000;  // 0.0

    coeff_imag_a[44][4] = 32'h00008000;  // 0.5j

    idx_a[44][4] = 4'd7;
    coeff_real_a[44][5] = 32'h00000000;  // 0.0

    coeff_imag_a[44][5] = 32'hFFFF8000;  // -0.5j

    idx_a[44][5] = 4'd10;
    coeff_real_a[44][6] = 32'h00000000;  // 0.0

    coeff_imag_a[44][6] = 32'h00008000;  // 0.5j

    idx_a[44][6] = 4'd11;
    coeff_real_a[44][7] = 32'h00000000;  // 0.0

    coeff_imag_a[44][7] = 32'hFFFF8000;  // -0.5j

    idx_a[44][7] = 4'd14;

    // a45 computation

    coeff_real_a[45][0] = 32'h00010000;  // 1.0

    coeff_imag_a[45][0] = 32'h00000000;  // 0.0j

    idx_a[45][0] = 4'd0;
    coeff_real_a[45][1] = 32'h00000000;  // 0.0

    coeff_imag_a[45][1] = 32'h00008000;  // 0.5j

    idx_a[45][1] = 4'd0;
    coeff_real_a[45][2] = 32'h00000000;  // 0.0

    coeff_imag_a[45][2] = 32'hFFFF8000;  // -0.5j

    idx_a[45][2] = 4'd1;
    coeff_real_a[45][3] = 32'h00000000;  // 0.0

    coeff_imag_a[45][3] = 32'h00008000;  // 0.5j

    idx_a[45][3] = 4'd4;
    coeff_real_a[45][4] = 32'h00000000;  // 0.0

    coeff_imag_a[45][4] = 32'hFFFF8000;  // -0.5j

    idx_a[45][4] = 4'd5;
    coeff_real_a[45][5] = 32'h00000000;  // 0.0

    coeff_imag_a[45][5] = 32'hFFFF8000;  // -0.5j

    idx_a[45][5] = 4'd8;
    coeff_real_a[45][6] = 32'h00000000;  // 0.0

    coeff_imag_a[45][6] = 32'h00008000;  // 0.5j

    idx_a[45][6] = 4'd9;
    coeff_real_a[45][7] = 32'h00000000;  // 0.0

    coeff_imag_a[45][7] = 32'hFFFF8000;  // -0.5j

    idx_a[45][7] = 4'd12;

    // a46 computation

    coeff_real_a[46][0] = 32'h00010000;  // 1.0

    coeff_imag_a[46][0] = 32'h00000000;  // 0.0j

    idx_a[46][0] = 4'd0;
    coeff_real_a[46][1] = 32'h00000000;  // 0.0

    coeff_imag_a[46][1] = 32'hFFFF8000;  // -0.5j

    idx_a[46][1] = 4'd0;
    coeff_real_a[46][2] = 32'h00000000;  // 0.0

    coeff_imag_a[46][2] = 32'h00008000;  // 0.5j

    idx_a[46][2] = 4'd3;
    coeff_real_a[46][3] = 32'h00000000;  // 0.0

    coeff_imag_a[46][3] = 32'hFFFF8000;  // -0.5j

    idx_a[46][3] = 4'd4;
    coeff_real_a[46][4] = 32'h00000000;  // 0.0

    coeff_imag_a[46][4] = 32'h00008000;  // 0.5j

    idx_a[46][4] = 4'd7;
    coeff_real_a[46][5] = 32'h00000000;  // 0.0

    coeff_imag_a[46][5] = 32'hFFFF8000;  // -0.5j

    idx_a[46][5] = 4'd8;
    coeff_real_a[46][6] = 32'h00000000;  // 0.0

    coeff_imag_a[46][6] = 32'h00008000;  // 0.5j

    idx_a[46][6] = 4'd11;
    coeff_real_a[46][7] = 32'h00000000;  // 0.0

    coeff_imag_a[46][7] = 32'h00008000;  // 0.5j

    idx_a[46][7] = 4'd12;

    // a47 computation

    coeff_real_a[47][0] = 32'h00008000;  // 0.5

    coeff_imag_a[47][0] = 32'h00000000;  // 0.0j

    idx_a[47][0] = 4'd0;
    coeff_real_a[47][1] = 32'h00000000;  // 0.0

    coeff_imag_a[47][1] = 32'h00008000;  // 0.5j

    idx_a[47][1] = 4'd1;
    coeff_real_a[47][2] = 32'h00000000;  // 0.0

    coeff_imag_a[47][2] = 32'h00008000;  // 0.5j

    idx_a[47][2] = 4'd2;
    coeff_real_a[47][3] = 32'h00000000;  // 0.0

    coeff_imag_a[47][3] = 32'hFFFF8000;  // -0.5j

    idx_a[47][3] = 4'd3;
    coeff_real_a[47][4] = 32'h00000000;  // 0.0

    coeff_imag_a[47][4] = 32'h00008000;  // 0.5j

    idx_a[47][4] = 4'd4;
    coeff_real_a[47][5] = 32'h00008000;  // 0.5

    coeff_imag_a[47][5] = 32'h00000000;  // 0.0j

    idx_a[47][5] = 4'd5;
    coeff_real_a[47][6] = 32'h00008000;  // 0.5

    coeff_imag_a[47][6] = 32'h00000000;  // 0.0j

    idx_a[47][6] = 4'd6;
    coeff_real_a[47][7] = 32'h00008000;  // 0.5

    coeff_imag_a[47][7] = 32'h00000000;  // 0.0j

    idx_a[47][7] = 4'd7;

    // B coefficients

    // b0 computation

    coeff_real_b[0][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[0][0] = 32'h00000000;  // 0.0j

    idx_b[0][0] = 4'd0;
    coeff_real_b[0][1] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[0][1] = 32'h00000000;  // 0.0j

    idx_b[0][1] = 4'd4;
    coeff_real_b[0][2] = 32'h00008000;  // 0.5

    coeff_imag_b[0][2] = 32'h00000000;  // 0.0j

    idx_b[0][2] = 4'd8;
    coeff_real_b[0][3] = 32'h00000000;  // 0.0

    coeff_imag_b[0][3] = 32'hFFFF8000;  // -0.5j

    idx_b[0][3] = 4'd12;

    // b1 computation

    coeff_real_b[1][0] = 32'h00000000;  // 0.0

    coeff_imag_b[1][0] = 32'h00008000;  // 0.5j

    idx_b[1][0] = 4'd1;
    coeff_real_b[1][1] = 32'h00000000;  // 0.0

    coeff_imag_b[1][1] = 32'h00008000;  // 0.5j

    idx_b[1][1] = 4'd3;
    coeff_real_b[1][2] = 32'h00000000;  // 0.0

    coeff_imag_b[1][2] = 32'h00008000;  // 0.5j

    idx_b[1][2] = 4'd5;
    coeff_real_b[1][3] = 32'h00000000;  // 0.0

    coeff_imag_b[1][3] = 32'h00008000;  // 0.5j

    idx_b[1][3] = 4'd7;
    coeff_real_b[1][4] = 32'h00000000;  // 0.0

    coeff_imag_b[1][4] = 32'h00008000;  // 0.5j

    idx_b[1][4] = 4'd9;
    coeff_real_b[1][5] = 32'h00000000;  // 0.0

    coeff_imag_b[1][5] = 32'h00008000;  // 0.5j

    idx_b[1][5] = 4'd11;
    coeff_real_b[1][6] = 32'h00008000;  // 0.5

    coeff_imag_b[1][6] = 32'h00000000;  // 0.0j

    idx_b[1][6] = 4'd13;
    coeff_real_b[1][7] = 32'h00008000;  // 0.5

    coeff_imag_b[1][7] = 32'h00000000;  // 0.0j

    idx_b[1][7] = 4'd15;

    // b2 computation

    coeff_real_b[2][0] = 32'h00010000;  // 1.0

    coeff_imag_b[2][0] = 32'h00000000;  // 0.0j

    idx_b[2][0] = 4'd0;
    coeff_real_b[2][1] = 32'h00000000;  // 0.0

    coeff_imag_b[2][1] = 32'h00008000;  // 0.5j

    idx_b[2][1] = 4'd1;
    coeff_real_b[2][2] = 32'h00000000;  // 0.0

    coeff_imag_b[2][2] = 32'hFFFF8000;  // -0.5j

    idx_b[2][2] = 4'd5;
    coeff_real_b[2][3] = 32'h00000000;  // 0.0

    coeff_imag_b[2][3] = 32'h00008000;  // 0.5j

    idx_b[2][3] = 4'd9;
    coeff_real_b[2][4] = 32'h00000000;  // 0.0

    coeff_imag_b[2][4] = 32'hFFFF8000;  // -0.5j

    idx_b[2][4] = 4'd13;

    // b3 computation

    coeff_real_b[3][0] = 32'h00000000;  // 0.0

    coeff_imag_b[3][0] = 32'hFFFF8000;  // -0.5j

    idx_b[3][0] = 4'd0;
    coeff_real_b[3][1] = 32'h00000000;  // 0.0

    coeff_imag_b[3][1] = 32'h00008000;  // 0.5j

    idx_b[3][1] = 4'd2;
    coeff_real_b[3][2] = 32'h00000000;  // 0.0

    coeff_imag_b[3][2] = 32'hFFFF8000;  // -0.5j

    idx_b[3][2] = 4'd5;
    coeff_real_b[3][3] = 32'h00000000;  // 0.0

    coeff_imag_b[3][3] = 32'hFFFF8000;  // -0.5j

    idx_b[3][3] = 4'd6;
    coeff_real_b[3][4] = 32'h00000000;  // 0.0

    coeff_imag_b[3][4] = 32'h00008000;  // 0.5j

    idx_b[3][4] = 4'd9;
    coeff_real_b[3][5] = 32'h00000000;  // 0.0

    coeff_imag_b[3][5] = 32'h00008000;  // 0.5j

    idx_b[3][5] = 4'd10;
    coeff_real_b[3][6] = 32'h00008000;  // 0.5

    coeff_imag_b[3][6] = 32'h00000000;  // 0.0j

    idx_b[3][6] = 4'd12;
    coeff_real_b[3][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[3][7] = 32'h00000000;  // 0.0j

    idx_b[3][7] = 4'd14;

    // b4 computation

    coeff_real_b[4][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[4][0] = 32'h00000000;  // 0.0j

    idx_b[4][0] = 4'd0;
    coeff_real_b[4][1] = 32'h00008000;  // 0.5

    coeff_imag_b[4][1] = 32'h00000000;  // 0.0j

    idx_b[4][1] = 4'd2;
    coeff_real_b[4][2] = 32'h00008000;  // 0.5

    coeff_imag_b[4][2] = 32'h00000000;  // 0.0j

    idx_b[4][2] = 4'd3;
    coeff_real_b[4][3] = 32'h00008000;  // 0.5

    coeff_imag_b[4][3] = 32'h00000000;  // 0.0j

    idx_b[4][3] = 4'd4;
    coeff_real_b[4][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[4][4] = 32'h00000000;  // 0.0j

    idx_b[4][4] = 4'd6;
    coeff_real_b[4][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[4][5] = 32'h00000000;  // 0.0j

    idx_b[4][5] = 4'd7;
    coeff_real_b[4][6] = 32'h00008000;  // 0.5

    coeff_imag_b[4][6] = 32'h00000000;  // 0.0j

    idx_b[4][6] = 4'd8;
    coeff_real_b[4][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[4][7] = 32'h00000000;  // 0.0j

    idx_b[4][7] = 4'd10;

    // b5 computation

    coeff_real_b[5][0] = 32'h00008000;  // 0.5

    coeff_imag_b[5][0] = 32'h00000000;  // 0.0j

    idx_b[5][0] = 4'd1;
    coeff_real_b[5][1] = 32'h00008000;  // 0.5

    coeff_imag_b[5][1] = 32'h00000000;  // 0.0j

    idx_b[5][1] = 4'd3;
    coeff_real_b[5][2] = 32'h00008000;  // 0.5

    coeff_imag_b[5][2] = 32'h00000000;  // 0.0j

    idx_b[5][2] = 4'd5;
    coeff_real_b[5][3] = 32'h00008000;  // 0.5

    coeff_imag_b[5][3] = 32'h00000000;  // 0.0j

    idx_b[5][3] = 4'd7;
    coeff_real_b[5][4] = 32'h00008000;  // 0.5

    coeff_imag_b[5][4] = 32'h00000000;  // 0.0j

    idx_b[5][4] = 4'd9;
    coeff_real_b[5][5] = 32'h00008000;  // 0.5

    coeff_imag_b[5][5] = 32'h00000000;  // 0.0j

    idx_b[5][5] = 4'd11;
    coeff_real_b[5][6] = 32'h00000000;  // 0.0

    coeff_imag_b[5][6] = 32'h00008000;  // 0.5j

    idx_b[5][6] = 4'd13;
    coeff_real_b[5][7] = 32'h00000000;  // 0.0

    coeff_imag_b[5][7] = 32'h00008000;  // 0.5j

    idx_b[5][7] = 4'd15;

    // b6 computation

    coeff_real_b[6][0] = 32'h00010000;  // 1.0

    coeff_imag_b[6][0] = 32'h00000000;  // 0.0j

    idx_b[6][0] = 4'd0;
    coeff_real_b[6][1] = 32'h00000000;  // 0.0

    coeff_imag_b[6][1] = 32'hFFFF8000;  // -0.5j

    idx_b[6][1] = 4'd1;
    coeff_real_b[6][2] = 32'h00000000;  // 0.0

    coeff_imag_b[6][2] = 32'h00008000;  // 0.5j

    idx_b[6][2] = 4'd5;
    coeff_real_b[6][3] = 32'h00000000;  // 0.0

    coeff_imag_b[6][3] = 32'h00008000;  // 0.5j

    idx_b[6][3] = 4'd9;
    coeff_real_b[6][4] = 32'h00000000;  // 0.0

    coeff_imag_b[6][4] = 32'hFFFF8000;  // -0.5j

    idx_b[6][4] = 4'd13;

    // b7 computation

    coeff_real_b[7][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[7][0] = 32'h00000000;  // 0.0j

    idx_b[7][0] = 4'd0;
    coeff_real_b[7][1] = 32'h00008000;  // 0.5

    coeff_imag_b[7][1] = 32'h00000000;  // 0.0j

    idx_b[7][1] = 4'd3;
    coeff_real_b[7][2] = 32'h00008000;  // 0.5

    coeff_imag_b[7][2] = 32'h00000000;  // 0.0j

    idx_b[7][2] = 4'd4;
    coeff_real_b[7][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[7][3] = 32'h00000000;  // 0.0j

    idx_b[7][3] = 4'd7;
    coeff_real_b[7][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[7][4] = 32'h00000000;  // 0.0j

    idx_b[7][4] = 4'd8;
    coeff_real_b[7][5] = 32'h00008000;  // 0.5

    coeff_imag_b[7][5] = 32'h00000000;  // 0.0j

    idx_b[7][5] = 4'd11;
    coeff_real_b[7][6] = 32'h00000000;  // 0.0

    coeff_imag_b[7][6] = 32'h00008000;  // 0.5j

    idx_b[7][6] = 4'd12;
    coeff_real_b[7][7] = 32'h00000000;  // 0.0

    coeff_imag_b[7][7] = 32'hFFFF8000;  // -0.5j

    idx_b[7][7] = 4'd15;

    // b8 computation

    coeff_real_b[8][0] = 32'h00008000;  // 0.5

    coeff_imag_b[8][0] = 32'h00000000;  // 0.0j

    idx_b[8][0] = 4'd0;
    coeff_real_b[8][1] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[8][1] = 32'h00000000;  // 0.0j

    idx_b[8][1] = 4'd2;
    coeff_real_b[8][2] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[8][2] = 32'h00000000;  // 0.0j

    idx_b[8][2] = 4'd3;
    coeff_real_b[8][3] = 32'h00008000;  // 0.5

    coeff_imag_b[8][3] = 32'h00000000;  // 0.0j

    idx_b[8][3] = 4'd4;
    coeff_real_b[8][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[8][4] = 32'h00000000;  // 0.0j

    idx_b[8][4] = 4'd6;
    coeff_real_b[8][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[8][5] = 32'h00000000;  // 0.0j

    idx_b[8][5] = 4'd7;
    coeff_real_b[8][6] = 32'h00008000;  // 0.5

    coeff_imag_b[8][6] = 32'h00000000;  // 0.0j

    idx_b[8][6] = 4'd9;
    coeff_real_b[8][7] = 32'h00000000;  // 0.0

    coeff_imag_b[8][7] = 32'hFFFF8000;  // -0.5j

    idx_b[8][7] = 4'd13;

    // b9 computation

    coeff_real_b[9][0] = 32'h00000000;  // 0.0

    coeff_imag_b[9][0] = 32'h00008000;  // 0.5j

    idx_b[9][0] = 4'd1;
    coeff_real_b[9][1] = 32'h00000000;  // 0.0

    coeff_imag_b[9][1] = 32'h00008000;  // 0.5j

    idx_b[9][1] = 4'd2;
    coeff_real_b[9][2] = 32'h00000000;  // 0.0

    coeff_imag_b[9][2] = 32'h00008000;  // 0.5j

    idx_b[9][2] = 4'd3;
    coeff_real_b[9][3] = 32'h00000000;  // 0.0

    coeff_imag_b[9][3] = 32'h00008000;  // 0.5j

    idx_b[9][3] = 4'd5;
    coeff_real_b[9][4] = 32'h00000000;  // 0.0

    coeff_imag_b[9][4] = 32'h00008000;  // 0.5j

    idx_b[9][4] = 4'd6;
    coeff_real_b[9][5] = 32'h00000000;  // 0.0

    coeff_imag_b[9][5] = 32'h00008000;  // 0.5j

    idx_b[9][5] = 4'd7;
    coeff_real_b[9][6] = 32'h00000000;  // 0.0

    coeff_imag_b[9][6] = 32'hFFFF8000;  // -0.5j

    idx_b[9][6] = 4'd9;
    coeff_real_b[9][7] = 32'h00000000;  // 0.0

    coeff_imag_b[9][7] = 32'hFFFF8000;  // -0.5j

    idx_b[9][7] = 4'd10;

    // b10 computation

    coeff_real_b[10][0] = 32'h00000000;  // 0.0

    coeff_imag_b[10][0] = 32'h00008000;  // 0.5j

    idx_b[10][0] = 4'd1;
    coeff_real_b[10][1] = 32'h00000000;  // 0.0

    coeff_imag_b[10][1] = 32'h00008000;  // 0.5j

    idx_b[10][1] = 4'd3;
    coeff_real_b[10][2] = 32'h00000000;  // 0.0

    coeff_imag_b[10][2] = 32'hFFFF8000;  // -0.5j

    idx_b[10][2] = 4'd5;
    coeff_real_b[10][3] = 32'h00000000;  // 0.0

    coeff_imag_b[10][3] = 32'hFFFF8000;  // -0.5j

    idx_b[10][3] = 4'd7;
    coeff_real_b[10][4] = 32'h00000000;  // 0.0

    coeff_imag_b[10][4] = 32'hFFFF8000;  // -0.5j

    idx_b[10][4] = 4'd9;
    coeff_real_b[10][5] = 32'h00000000;  // 0.0

    coeff_imag_b[10][5] = 32'hFFFF8000;  // -0.5j

    idx_b[10][5] = 4'd11;
    coeff_real_b[10][6] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[10][6] = 32'h00000000;  // 0.0j

    idx_b[10][6] = 4'd13;
    coeff_real_b[10][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[10][7] = 32'h00000000;  // 0.0j

    idx_b[10][7] = 4'd15;

    // b11 computation

    coeff_real_b[11][0] = 32'h00000000;  // 0.0

    coeff_imag_b[11][0] = 32'hFFFF8000;  // -0.5j

    idx_b[11][0] = 4'd0;
    coeff_real_b[11][1] = 32'h00000000;  // 0.0

    coeff_imag_b[11][1] = 32'h00008000;  // 0.5j

    idx_b[11][1] = 4'd3;
    coeff_real_b[11][2] = 32'h00000000;  // 0.0

    coeff_imag_b[11][2] = 32'hFFFF8000;  // -0.5j

    idx_b[11][2] = 4'd4;
    coeff_real_b[11][3] = 32'h00000000;  // 0.0

    coeff_imag_b[11][3] = 32'h00008000;  // 0.5j

    idx_b[11][3] = 4'd7;
    coeff_real_b[11][4] = 32'h00000000;  // 0.0

    coeff_imag_b[11][4] = 32'h00008000;  // 0.5j

    idx_b[11][4] = 4'd9;
    coeff_real_b[11][5] = 32'h00000000;  // 0.0

    coeff_imag_b[11][5] = 32'h00008000;  // 0.5j

    idx_b[11][5] = 4'd10;
    coeff_real_b[11][6] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[11][6] = 32'h00000000;  // 0.0j

    idx_b[11][6] = 4'd13;
    coeff_real_b[11][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[11][7] = 32'h00000000;  // 0.0j

    idx_b[11][7] = 4'd14;

    // b12 computation

    coeff_real_b[12][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[12][0] = 32'h00000000;  // 0.0j

    idx_b[12][0] = 4'd0;
    coeff_real_b[12][1] = 32'h00008000;  // 0.5

    coeff_imag_b[12][1] = 32'h00000000;  // 0.0j

    idx_b[12][1] = 4'd2;
    coeff_real_b[12][2] = 32'h00008000;  // 0.5

    coeff_imag_b[12][2] = 32'h00000000;  // 0.0j

    idx_b[12][2] = 4'd3;
    coeff_real_b[12][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[12][3] = 32'h00000000;  // 0.0j

    idx_b[12][3] = 4'd4;
    coeff_real_b[12][4] = 32'h00008000;  // 0.5

    coeff_imag_b[12][4] = 32'h00000000;  // 0.0j

    idx_b[12][4] = 4'd6;
    coeff_real_b[12][5] = 32'h00008000;  // 0.5

    coeff_imag_b[12][5] = 32'h00000000;  // 0.0j

    idx_b[12][5] = 4'd7;
    coeff_real_b[12][6] = 32'h00008000;  // 0.5

    coeff_imag_b[12][6] = 32'h00000000;  // 0.0j

    idx_b[12][6] = 4'd8;
    coeff_real_b[12][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[12][7] = 32'h00000000;  // 0.0j

    idx_b[12][7] = 4'd10;

    // b13 computation

    coeff_real_b[13][0] = 32'h00000000;  // 0.0

    coeff_imag_b[13][0] = 32'h00008000;  // 0.5j

    idx_b[13][0] = 4'd0;
    coeff_real_b[13][1] = 32'h00000000;  // 0.0

    coeff_imag_b[13][1] = 32'hFFFF8000;  // -0.5j

    idx_b[13][1] = 4'd2;
    coeff_real_b[13][2] = 32'h00000000;  // 0.0

    coeff_imag_b[13][2] = 32'hFFFF8000;  // -0.5j

    idx_b[13][2] = 4'd4;
    coeff_real_b[13][3] = 32'h00000000;  // 0.0

    coeff_imag_b[13][3] = 32'h00008000;  // 0.5j

    idx_b[13][3] = 4'd6;
    coeff_real_b[13][4] = 32'h00000000;  // 0.0

    coeff_imag_b[13][4] = 32'h00008000;  // 0.5j

    idx_b[13][4] = 4'd8;
    coeff_real_b[13][5] = 32'h00000000;  // 0.0

    coeff_imag_b[13][5] = 32'hFFFF8000;  // -0.5j

    idx_b[13][5] = 4'd10;
    coeff_real_b[13][6] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[13][6] = 32'h00000000;  // 0.0j

    idx_b[13][6] = 4'd12;
    coeff_real_b[13][7] = 32'h00008000;  // 0.5

    coeff_imag_b[13][7] = 32'h00000000;  // 0.0j

    idx_b[13][7] = 4'd14;

    // b14 computation

    coeff_real_b[14][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[14][0] = 32'h00000000;  // 0.0j

    idx_b[14][0] = 4'd1;
    coeff_real_b[14][1] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[14][1] = 32'h00000000;  // 0.0j

    idx_b[14][1] = 4'd4;
    coeff_real_b[14][2] = 32'h00008000;  // 0.5

    coeff_imag_b[14][2] = 32'h00000000;  // 0.0j

    idx_b[14][2] = 4'd8;
    coeff_real_b[14][3] = 32'h00000000;  // 0.0

    coeff_imag_b[14][3] = 32'h00008000;  // 0.5j

    idx_b[14][3] = 4'd13;

    // b15 computation

    coeff_real_b[15][0] = 32'h00000000;  // 0.0

    coeff_imag_b[15][0] = 32'h00008000;  // 0.5j

    idx_b[15][0] = 4'd0;
    coeff_real_b[15][1] = 32'h00000000;  // 0.0

    coeff_imag_b[15][1] = 32'hFFFF8000;  // -0.5j

    idx_b[15][1] = 4'd3;
    coeff_real_b[15][2] = 32'h00000000;  // 0.0

    coeff_imag_b[15][2] = 32'h00008000;  // 0.5j

    idx_b[15][2] = 4'd4;
    coeff_real_b[15][3] = 32'h00000000;  // 0.0

    coeff_imag_b[15][3] = 32'hFFFF8000;  // -0.5j

    idx_b[15][3] = 4'd7;
    coeff_real_b[15][4] = 32'h00000000;  // 0.0

    coeff_imag_b[15][4] = 32'hFFFF8000;  // -0.5j

    idx_b[15][4] = 4'd8;
    coeff_real_b[15][5] = 32'h00000000;  // 0.0

    coeff_imag_b[15][5] = 32'h00008000;  // 0.5j

    idx_b[15][5] = 4'd11;
    coeff_real_b[15][6] = 32'h00008000;  // 0.5

    coeff_imag_b[15][6] = 32'h00000000;  // 0.0j

    idx_b[15][6] = 4'd12;
    coeff_real_b[15][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[15][7] = 32'h00000000;  // 0.0j

    idx_b[15][7] = 4'd15;

    // b16 computation

    coeff_real_b[16][0] = 32'h00008000;  // 0.5

    coeff_imag_b[16][0] = 32'h00000000;  // 0.0j

    idx_b[16][0] = 4'd1;
    coeff_real_b[16][1] = 32'h00008000;  // 0.5

    coeff_imag_b[16][1] = 32'h00000000;  // 0.0j

    idx_b[16][1] = 4'd2;
    coeff_real_b[16][2] = 32'h00008000;  // 0.5

    coeff_imag_b[16][2] = 32'h00000000;  // 0.0j

    idx_b[16][2] = 4'd4;
    coeff_real_b[16][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[16][3] = 32'h00000000;  // 0.0j

    idx_b[16][3] = 4'd6;
    coeff_real_b[16][4] = 32'h00008000;  // 0.5

    coeff_imag_b[16][4] = 32'h00000000;  // 0.0j

    idx_b[16][4] = 4'd8;
    coeff_real_b[16][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[16][5] = 32'h00000000;  // 0.0j

    idx_b[16][5] = 4'd10;
    coeff_real_b[16][6] = 32'h00000000;  // 0.0

    coeff_imag_b[16][6] = 32'hFFFF8000;  // -0.5j

    idx_b[16][6] = 4'd13;
    coeff_real_b[16][7] = 32'h00000000;  // 0.0

    coeff_imag_b[16][7] = 32'hFFFF8000;  // -0.5j

    idx_b[16][7] = 4'd14;

    // b17 computation

    coeff_real_b[17][0] = 32'h00000000;  // 0.0

    coeff_imag_b[17][0] = 32'hFFFF8000;  // -0.5j

    idx_b[17][0] = 4'd0;
    coeff_real_b[17][1] = 32'h00000000;  // 0.0

    coeff_imag_b[17][1] = 32'h00008000;  // 0.5j

    idx_b[17][1] = 4'd2;
    coeff_real_b[17][2] = 32'h00000000;  // 0.0

    coeff_imag_b[17][2] = 32'hFFFF8000;  // -0.5j

    idx_b[17][2] = 4'd4;
    coeff_real_b[17][3] = 32'h00000000;  // 0.0

    coeff_imag_b[17][3] = 32'h00008000;  // 0.5j

    idx_b[17][3] = 4'd6;
    coeff_real_b[17][4] = 32'h00000000;  // 0.0

    coeff_imag_b[17][4] = 32'hFFFF8000;  // -0.5j

    idx_b[17][4] = 4'd8;
    coeff_real_b[17][5] = 32'h00000000;  // 0.0

    coeff_imag_b[17][5] = 32'h00008000;  // 0.5j

    idx_b[17][5] = 4'd10;
    coeff_real_b[17][6] = 32'h00008000;  // 0.5

    coeff_imag_b[17][6] = 32'h00000000;  // 0.0j

    idx_b[17][6] = 4'd12;
    coeff_real_b[17][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[17][7] = 32'h00000000;  // 0.0j

    idx_b[17][7] = 4'd14;

    // b18 computation

    coeff_real_b[18][0] = 32'h00000000;  // 0.0

    coeff_imag_b[18][0] = 32'hFFFF8000;  // -0.5j

    idx_b[18][0] = 4'd1;
    coeff_real_b[18][1] = 32'h00000000;  // 0.0

    coeff_imag_b[18][1] = 32'hFFFF8000;  // -0.5j

    idx_b[18][1] = 4'd3;
    coeff_real_b[18][2] = 32'h00000000;  // 0.0

    coeff_imag_b[18][2] = 32'hFFFF8000;  // -0.5j

    idx_b[18][2] = 4'd5;
    coeff_real_b[18][3] = 32'h00000000;  // 0.0

    coeff_imag_b[18][3] = 32'hFFFF8000;  // -0.5j

    idx_b[18][3] = 4'd7;
    coeff_real_b[18][4] = 32'h00000000;  // 0.0

    coeff_imag_b[18][4] = 32'hFFFF8000;  // -0.5j

    idx_b[18][4] = 4'd8;
    coeff_real_b[18][5] = 32'h00000000;  // 0.0

    coeff_imag_b[18][5] = 32'h00008000;  // 0.5j

    idx_b[18][5] = 4'd10;
    coeff_real_b[18][6] = 32'h00008000;  // 0.5

    coeff_imag_b[18][6] = 32'h00000000;  // 0.0j

    idx_b[18][6] = 4'd12;
    coeff_real_b[18][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[18][7] = 32'h00000000;  // 0.0j

    idx_b[18][7] = 4'd14;

    // b19 computation

    coeff_real_b[19][0] = 32'h00000000;  // 0.0

    coeff_imag_b[19][0] = 32'hFFFF8000;  // -0.5j

    idx_b[19][0] = 4'd0;
    coeff_real_b[19][1] = 32'h00000000;  // 0.0

    coeff_imag_b[19][1] = 32'h00008000;  // 0.5j

    idx_b[19][1] = 4'd2;
    coeff_real_b[19][2] = 32'h00000000;  // 0.0

    coeff_imag_b[19][2] = 32'h00008000;  // 0.5j

    idx_b[19][2] = 4'd4;
    coeff_real_b[19][3] = 32'h00000000;  // 0.0

    coeff_imag_b[19][3] = 32'hFFFF8000;  // -0.5j

    idx_b[19][3] = 4'd6;
    coeff_real_b[19][4] = 32'h00000000;  // 0.0

    coeff_imag_b[19][4] = 32'h00008000;  // 0.5j

    idx_b[19][4] = 4'd8;
    coeff_real_b[19][5] = 32'h00000000;  // 0.0

    coeff_imag_b[19][5] = 32'hFFFF8000;  // -0.5j

    idx_b[19][5] = 4'd10;
    coeff_real_b[19][6] = 32'h00008000;  // 0.5

    coeff_imag_b[19][6] = 32'h00000000;  // 0.0j

    idx_b[19][6] = 4'd12;
    coeff_real_b[19][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[19][7] = 32'h00000000;  // 0.0j

    idx_b[19][7] = 4'd14;

    // b20 computation

    coeff_real_b[20][0] = 32'h00000000;  // 0.0

    coeff_imag_b[20][0] = 32'hFFFF8000;  // -0.5j

    idx_b[20][0] = 4'd1;
    coeff_real_b[20][1] = 32'h00000000;  // 0.0

    coeff_imag_b[20][1] = 32'hFFFF8000;  // -0.5j

    idx_b[20][1] = 4'd3;
    coeff_real_b[20][2] = 32'h00000000;  // 0.0

    coeff_imag_b[20][2] = 32'hFFFF8000;  // -0.5j

    idx_b[20][2] = 4'd5;
    coeff_real_b[20][3] = 32'h00000000;  // 0.0

    coeff_imag_b[20][3] = 32'hFFFF8000;  // -0.5j

    idx_b[20][3] = 4'd7;
    coeff_real_b[20][4] = 32'h00000000;  // 0.0

    coeff_imag_b[20][4] = 32'h00008000;  // 0.5j

    idx_b[20][4] = 4'd9;
    coeff_real_b[20][5] = 32'h00000000;  // 0.0

    coeff_imag_b[20][5] = 32'h00008000;  // 0.5j

    idx_b[20][5] = 4'd11;
    coeff_real_b[20][6] = 32'h00008000;  // 0.5

    coeff_imag_b[20][6] = 32'h00000000;  // 0.0j

    idx_b[20][6] = 4'd13;
    coeff_real_b[20][7] = 32'h00008000;  // 0.5

    coeff_imag_b[20][7] = 32'h00000000;  // 0.0j

    idx_b[20][7] = 4'd15;

    // b21 computation

    coeff_real_b[21][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[21][0] = 32'h00000000;  // 0.0j

    idx_b[21][0] = 4'd1;
    coeff_real_b[21][1] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[21][1] = 32'h00000000;  // 0.0j

    idx_b[21][1] = 4'd2;
    coeff_real_b[21][2] = 32'h00008000;  // 0.5

    coeff_imag_b[21][2] = 32'h00000000;  // 0.0j

    idx_b[21][2] = 4'd5;
    coeff_real_b[21][3] = 32'h00008000;  // 0.5

    coeff_imag_b[21][3] = 32'h00000000;  // 0.0j

    idx_b[21][3] = 4'd6;
    coeff_real_b[21][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[21][4] = 32'h00000000;  // 0.0j

    idx_b[21][4] = 4'd8;
    coeff_real_b[21][5] = 32'h00008000;  // 0.5

    coeff_imag_b[21][5] = 32'h00000000;  // 0.0j

    idx_b[21][5] = 4'd11;
    coeff_real_b[21][6] = 32'h00000000;  // 0.0

    coeff_imag_b[21][6] = 32'h00008000;  // 0.5j

    idx_b[21][6] = 4'd12;
    coeff_real_b[21][7] = 32'h00000000;  // 0.0

    coeff_imag_b[21][7] = 32'hFFFF8000;  // -0.5j

    idx_b[21][7] = 4'd15;

    // b22 computation

    coeff_real_b[22][0] = 32'h00000000;  // 0.0

    coeff_imag_b[22][0] = 32'hFFFF8000;  // -0.5j

    idx_b[22][0] = 4'd0;
    coeff_real_b[22][1] = 32'h00000000;  // 0.0

    coeff_imag_b[22][1] = 32'h00008000;  // 0.5j

    idx_b[22][1] = 4'd2;
    coeff_real_b[22][2] = 32'h00000000;  // 0.0

    coeff_imag_b[22][2] = 32'h00008000;  // 0.5j

    idx_b[22][2] = 4'd3;
    coeff_real_b[22][3] = 32'h00000000;  // 0.0

    coeff_imag_b[22][3] = 32'hFFFF8000;  // -0.5j

    idx_b[22][3] = 4'd4;
    coeff_real_b[22][4] = 32'h00000000;  // 0.0

    coeff_imag_b[22][4] = 32'h00008000;  // 0.5j

    idx_b[22][4] = 4'd6;
    coeff_real_b[22][5] = 32'h00000000;  // 0.0

    coeff_imag_b[22][5] = 32'h00008000;  // 0.5j

    idx_b[22][5] = 4'd7;
    coeff_real_b[22][6] = 32'h00000000;  // 0.0

    coeff_imag_b[22][6] = 32'hFFFF8000;  // -0.5j

    idx_b[22][6] = 4'd8;
    coeff_real_b[22][7] = 32'h00000000;  // 0.0

    coeff_imag_b[22][7] = 32'h00008000;  // 0.5j

    idx_b[22][7] = 4'd10;

    // b23 computation

    coeff_real_b[23][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[23][0] = 32'h00000000;  // 0.0j

    idx_b[23][0] = 4'd0;
    coeff_real_b[23][1] = 32'h00008000;  // 0.5

    coeff_imag_b[23][1] = 32'h00000000;  // 0.0j

    idx_b[23][1] = 4'd2;
    coeff_real_b[23][2] = 32'h00008000;  // 0.5

    coeff_imag_b[23][2] = 32'h00000000;  // 0.0j

    idx_b[23][2] = 4'd3;
    coeff_real_b[23][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[23][3] = 32'h00000000;  // 0.0j

    idx_b[23][3] = 4'd4;
    coeff_real_b[23][4] = 32'h00008000;  // 0.5

    coeff_imag_b[23][4] = 32'h00000000;  // 0.0j

    idx_b[23][4] = 4'd6;
    coeff_real_b[23][5] = 32'h00008000;  // 0.5

    coeff_imag_b[23][5] = 32'h00000000;  // 0.0j

    idx_b[23][5] = 4'd7;
    coeff_real_b[23][6] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[23][6] = 32'h00000000;  // 0.0j

    idx_b[23][6] = 4'd8;
    coeff_real_b[23][7] = 32'h00008000;  // 0.5

    coeff_imag_b[23][7] = 32'h00000000;  // 0.0j

    idx_b[23][7] = 4'd10;

    // b24 computation

    coeff_real_b[24][0] = 32'h00000000;  // 0.0

    coeff_imag_b[24][0] = 32'h00008000;  // 0.5j

    idx_b[24][0] = 4'd1;
    coeff_real_b[24][1] = 32'h00000000;  // 0.0

    coeff_imag_b[24][1] = 32'hFFFF8000;  // -0.5j

    idx_b[24][1] = 4'd5;
    coeff_real_b[24][2] = 32'h00000000;  // 0.0

    coeff_imag_b[24][2] = 32'hFFFF8000;  // -0.5j

    idx_b[24][2] = 4'd8;
    coeff_real_b[24][3] = 32'h00000000;  // 0.0

    coeff_imag_b[24][3] = 32'h00008000;  // 0.5j

    idx_b[24][3] = 4'd10;
    coeff_real_b[24][4] = 32'h00000000;  // 0.0

    coeff_imag_b[24][4] = 32'h00008000;  // 0.5j

    idx_b[24][4] = 4'd11;
    coeff_real_b[24][5] = 32'h00008000;  // 0.5

    coeff_imag_b[24][5] = 32'h00000000;  // 0.0j

    idx_b[24][5] = 4'd12;
    coeff_real_b[24][6] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[24][6] = 32'h00000000;  // 0.0j

    idx_b[24][6] = 4'd14;
    coeff_real_b[24][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[24][7] = 32'h00000000;  // 0.0j

    idx_b[24][7] = 4'd15;

    // b25 computation

    coeff_real_b[25][0] = 32'h00000000;  // 0.0

    coeff_imag_b[25][0] = 32'h00008000;  // 0.5j

    idx_b[25][0] = 4'd1;
    coeff_real_b[25][1] = 32'h00000000;  // 0.0

    coeff_imag_b[25][1] = 32'h00008000;  // 0.5j

    idx_b[25][1] = 4'd2;
    coeff_real_b[25][2] = 32'h00000000;  // 0.0

    coeff_imag_b[25][2] = 32'h00008000;  // 0.5j

    idx_b[25][2] = 4'd3;
    coeff_real_b[25][3] = 32'h00000000;  // 0.0

    coeff_imag_b[25][3] = 32'h00008000;  // 0.5j

    idx_b[25][3] = 4'd5;
    coeff_real_b[25][4] = 32'h00000000;  // 0.0

    coeff_imag_b[25][4] = 32'h00008000;  // 0.5j

    idx_b[25][4] = 4'd6;
    coeff_real_b[25][5] = 32'h00000000;  // 0.0

    coeff_imag_b[25][5] = 32'h00008000;  // 0.5j

    idx_b[25][5] = 4'd7;
    coeff_real_b[25][6] = 32'h00000000;  // 0.0

    coeff_imag_b[25][6] = 32'hFFFF8000;  // -0.5j

    idx_b[25][6] = 4'd9;
    coeff_real_b[25][7] = 32'h00000000;  // 0.0

    coeff_imag_b[25][7] = 32'hFFFF8000;  // -0.5j

    idx_b[25][7] = 4'd10;

    // b26 computation

    coeff_real_b[26][0] = 32'h00008000;  // 0.5

    coeff_imag_b[26][0] = 32'h00000000;  // 0.0j

    idx_b[26][0] = 4'd1;
    coeff_real_b[26][1] = 32'h00008000;  // 0.5

    coeff_imag_b[26][1] = 32'h00000000;  // 0.0j

    idx_b[26][1] = 4'd2;
    coeff_real_b[26][2] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[26][2] = 32'h00000000;  // 0.0j

    idx_b[26][2] = 4'd5;
    coeff_real_b[26][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[26][3] = 32'h00000000;  // 0.0j

    idx_b[26][3] = 4'd6;
    coeff_real_b[26][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[26][4] = 32'h00000000;  // 0.0j

    idx_b[26][4] = 4'd9;
    coeff_real_b[26][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[26][5] = 32'h00000000;  // 0.0j

    idx_b[26][5] = 4'd10;
    coeff_real_b[26][6] = 32'h00000000;  // 0.0

    coeff_imag_b[26][6] = 32'hFFFF8000;  // -0.5j

    idx_b[26][6] = 4'd13;
    coeff_real_b[26][7] = 32'h00000000;  // 0.0

    coeff_imag_b[26][7] = 32'hFFFF8000;  // -0.5j

    idx_b[26][7] = 4'd14;

    // b27 computation

    coeff_real_b[27][0] = 32'h00000000;  // 0.0

    coeff_imag_b[27][0] = 32'h00008000;  // 0.5j

    idx_b[27][0] = 4'd1;
    coeff_real_b[27][1] = 32'h00000000;  // 0.0

    coeff_imag_b[27][1] = 32'h00008000;  // 0.5j

    idx_b[27][1] = 4'd2;
    coeff_real_b[27][2] = 32'h00000000;  // 0.0

    coeff_imag_b[27][2] = 32'h00008000;  // 0.5j

    idx_b[27][2] = 4'd3;
    coeff_real_b[27][3] = 32'h00000000;  // 0.0

    coeff_imag_b[27][3] = 32'h00008000;  // 0.5j

    idx_b[27][3] = 4'd5;
    coeff_real_b[27][4] = 32'h00000000;  // 0.0

    coeff_imag_b[27][4] = 32'h00008000;  // 0.5j

    idx_b[27][4] = 4'd6;
    coeff_real_b[27][5] = 32'h00000000;  // 0.0

    coeff_imag_b[27][5] = 32'h00008000;  // 0.5j

    idx_b[27][5] = 4'd7;
    coeff_real_b[27][6] = 32'h00000000;  // 0.0

    coeff_imag_b[27][6] = 32'hFFFF8000;  // -0.5j

    idx_b[27][6] = 4'd8;
    coeff_real_b[27][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[27][7] = 32'h00000000;  // 0.0j

    idx_b[27][7] = 4'd12;

    // b28 computation

    coeff_real_b[28][0] = 32'h00008000;  // 0.5

    coeff_imag_b[28][0] = 32'h00000000;  // 0.0j

    idx_b[28][0] = 4'd1;
    coeff_real_b[28][1] = 32'h00008000;  // 0.5

    coeff_imag_b[28][1] = 32'h00000000;  // 0.0j

    idx_b[28][1] = 4'd5;
    coeff_real_b[28][2] = 32'h00008000;  // 0.5

    coeff_imag_b[28][2] = 32'h00000000;  // 0.0j

    idx_b[28][2] = 4'd9;
    coeff_real_b[28][3] = 32'h00000000;  // 0.0

    coeff_imag_b[28][3] = 32'hFFFF8000;  // -0.5j

    idx_b[28][3] = 4'd13;

    // b29 computation

    coeff_real_b[29][0] = 32'h00000000;  // 0.0

    coeff_imag_b[29][0] = 32'h00008000;  // 0.5j

    idx_b[29][0] = 4'd1;
    coeff_real_b[29][1] = 32'h00000000;  // 0.0

    coeff_imag_b[29][1] = 32'h00008000;  // 0.5j

    idx_b[29][1] = 4'd2;
    coeff_real_b[29][2] = 32'h00000000;  // 0.0

    coeff_imag_b[29][2] = 32'hFFFF8000;  // -0.5j

    idx_b[29][2] = 4'd5;
    coeff_real_b[29][3] = 32'h00000000;  // 0.0

    coeff_imag_b[29][3] = 32'hFFFF8000;  // -0.5j

    idx_b[29][3] = 4'd6;
    coeff_real_b[29][4] = 32'h00000000;  // 0.0

    coeff_imag_b[29][4] = 32'h00008000;  // 0.5j

    idx_b[29][4] = 4'd9;
    coeff_real_b[29][5] = 32'h00000000;  // 0.0

    coeff_imag_b[29][5] = 32'h00008000;  // 0.5j

    idx_b[29][5] = 4'd10;
    coeff_real_b[29][6] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[29][6] = 32'h00000000;  // 0.0j

    idx_b[29][6] = 4'd13;
    coeff_real_b[29][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[29][7] = 32'h00000000;  // 0.0j

    idx_b[29][7] = 4'd14;

    // b30 computation

    coeff_real_b[30][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[30][0] = 32'h00000000;  // 0.0j

    idx_b[30][0] = 4'd0;
    coeff_real_b[30][1] = 32'h00008000;  // 0.5

    coeff_imag_b[30][1] = 32'h00000000;  // 0.0j

    idx_b[30][1] = 4'd3;
    coeff_real_b[30][2] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[30][2] = 32'h00000000;  // 0.0j

    idx_b[30][2] = 4'd4;
    coeff_real_b[30][3] = 32'h00008000;  // 0.5

    coeff_imag_b[30][3] = 32'h00000000;  // 0.0j

    idx_b[30][3] = 4'd7;
    coeff_real_b[30][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[30][4] = 32'h00000000;  // 0.0j

    idx_b[30][4] = 4'd8;
    coeff_real_b[30][5] = 32'h00008000;  // 0.5

    coeff_imag_b[30][5] = 32'h00000000;  // 0.0j

    idx_b[30][5] = 4'd11;
    coeff_real_b[30][6] = 32'h00000000;  // 0.0

    coeff_imag_b[30][6] = 32'h00008000;  // 0.5j

    idx_b[30][6] = 4'd12;
    coeff_real_b[30][7] = 32'h00000000;  // 0.0

    coeff_imag_b[30][7] = 32'hFFFF8000;  // -0.5j

    idx_b[30][7] = 4'd15;

    // b31 computation

    coeff_real_b[31][0] = 32'h00008000;  // 0.5

    coeff_imag_b[31][0] = 32'h00000000;  // 0.0j

    idx_b[31][0] = 4'd0;
    coeff_real_b[31][1] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[31][1] = 32'h00000000;  // 0.0j

    idx_b[31][1] = 4'd2;
    coeff_real_b[31][2] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[31][2] = 32'h00000000;  // 0.0j

    idx_b[31][2] = 4'd4;
    coeff_real_b[31][3] = 32'h00008000;  // 0.5

    coeff_imag_b[31][3] = 32'h00000000;  // 0.0j

    idx_b[31][3] = 4'd6;
    coeff_real_b[31][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[31][4] = 32'h00000000;  // 0.0j

    idx_b[31][4] = 4'd9;
    coeff_real_b[31][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[31][5] = 32'h00000000;  // 0.0j

    idx_b[31][5] = 4'd11;
    coeff_real_b[31][6] = 32'h00000000;  // 0.0

    coeff_imag_b[31][6] = 32'h00008000;  // 0.5j

    idx_b[31][6] = 4'd13;
    coeff_real_b[31][7] = 32'h00000000;  // 0.0

    coeff_imag_b[31][7] = 32'h00008000;  // 0.5j

    idx_b[31][7] = 4'd15;

    // b32 computation

    coeff_real_b[32][0] = 32'h00000000;  // 0.0

    coeff_imag_b[32][0] = 32'h00008000;  // 0.5j

    idx_b[32][0] = 4'd1;
    coeff_real_b[32][1] = 32'h00000000;  // 0.0

    coeff_imag_b[32][1] = 32'hFFFF8000;  // -0.5j

    idx_b[32][1] = 4'd5;
    coeff_real_b[32][2] = 32'h00000000;  // 0.0

    coeff_imag_b[32][2] = 32'hFFFF8000;  // -0.5j

    idx_b[32][2] = 4'd9;
    coeff_real_b[32][3] = 32'h00008000;  // 0.5

    coeff_imag_b[32][3] = 32'h00000000;  // 0.0j

    idx_b[32][3] = 4'd13;

    // b33 computation

    coeff_real_b[33][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[33][0] = 32'h00000000;  // 0.0j

    idx_b[33][0] = 4'd1;
    coeff_real_b[33][1] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[33][1] = 32'h00000000;  // 0.0j

    idx_b[33][1] = 4'd3;
    coeff_real_b[33][2] = 32'h00008000;  // 0.5

    coeff_imag_b[33][2] = 32'h00000000;  // 0.0j

    idx_b[33][2] = 4'd4;
    coeff_real_b[33][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[33][3] = 32'h00000000;  // 0.0j

    idx_b[33][3] = 4'd7;
    coeff_real_b[33][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[33][4] = 32'h00000000;  // 0.0j

    idx_b[33][4] = 4'd8;
    coeff_real_b[33][5] = 32'h00008000;  // 0.5

    coeff_imag_b[33][5] = 32'h00000000;  // 0.0j

    idx_b[33][5] = 4'd11;
    coeff_real_b[33][6] = 32'h00000000;  // 0.0

    coeff_imag_b[33][6] = 32'hFFFF8000;  // -0.5j

    idx_b[33][6] = 4'd13;
    coeff_real_b[33][7] = 32'h00000000;  // 0.0

    coeff_imag_b[33][7] = 32'hFFFF8000;  // -0.5j

    idx_b[33][7] = 4'd15;

    // b34 computation

    coeff_real_b[34][0] = 32'h00000000;  // 0.0

    coeff_imag_b[34][0] = 32'h00008000;  // 0.5j

    idx_b[34][0] = 4'd0;
    coeff_real_b[34][1] = 32'h00000000;  // 0.0

    coeff_imag_b[34][1] = 32'hFFFF8000;  // -0.5j

    idx_b[34][1] = 4'd4;
    coeff_real_b[34][2] = 32'h00000000;  // 0.0

    coeff_imag_b[34][2] = 32'h00008000;  // 0.5j

    idx_b[34][2] = 4'd9;
    coeff_real_b[34][3] = 32'h00000000;  // 0.0

    coeff_imag_b[34][3] = 32'h00008000;  // 0.5j

    idx_b[34][3] = 4'd10;
    coeff_real_b[34][4] = 32'h00000000;  // 0.0

    coeff_imag_b[34][4] = 32'h00008000;  // 0.5j

    idx_b[34][4] = 4'd11;
    coeff_real_b[34][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[34][5] = 32'h00000000;  // 0.0j

    idx_b[34][5] = 4'd13;
    coeff_real_b[34][6] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[34][6] = 32'h00000000;  // 0.0j

    idx_b[34][6] = 4'd14;
    coeff_real_b[34][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[34][7] = 32'h00000000;  // 0.0j

    idx_b[34][7] = 4'd15;

    // b35 computation

    coeff_real_b[35][0] = 32'h00000000;  // 0.0

    coeff_imag_b[35][0] = 32'hFFFF8000;  // -0.5j

    idx_b[35][0] = 4'd1;
    coeff_real_b[35][1] = 32'h00000000;  // 0.0

    coeff_imag_b[35][1] = 32'hFFFF8000;  // -0.5j

    idx_b[35][1] = 4'd2;
    coeff_real_b[35][2] = 32'h00000000;  // 0.0

    coeff_imag_b[35][2] = 32'h00008000;  // 0.5j

    idx_b[35][2] = 4'd5;
    coeff_real_b[35][3] = 32'h00000000;  // 0.0

    coeff_imag_b[35][3] = 32'h00008000;  // 0.5j

    idx_b[35][3] = 4'd6;
    coeff_real_b[35][4] = 32'h00000000;  // 0.0

    coeff_imag_b[35][4] = 32'hFFFF8000;  // -0.5j

    idx_b[35][4] = 4'd9;
    coeff_real_b[35][5] = 32'h00000000;  // 0.0

    coeff_imag_b[35][5] = 32'hFFFF8000;  // -0.5j

    idx_b[35][5] = 4'd10;
    coeff_real_b[35][6] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[35][6] = 32'h00000000;  // 0.0j

    idx_b[35][6] = 4'd13;
    coeff_real_b[35][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[35][7] = 32'h00000000;  // 0.0j

    idx_b[35][7] = 4'd14;

    // b36 computation

    coeff_real_b[36][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[36][0] = 32'h00000000;  // 0.0j

    idx_b[36][0] = 4'd1;
    coeff_real_b[36][1] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[36][1] = 32'h00000000;  // 0.0j

    idx_b[36][1] = 4'd2;
    coeff_real_b[36][2] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[36][2] = 32'h00000000;  // 0.0j

    idx_b[36][2] = 4'd3;
    coeff_real_b[36][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[36][3] = 32'h00000000;  // 0.0j

    idx_b[36][3] = 4'd5;
    coeff_real_b[36][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[36][4] = 32'h00000000;  // 0.0j

    idx_b[36][4] = 4'd6;
    coeff_real_b[36][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[36][5] = 32'h00000000;  // 0.0j

    idx_b[36][5] = 4'd7;
    coeff_real_b[36][6] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[36][6] = 32'h00000000;  // 0.0j

    idx_b[36][6] = 4'd9;
    coeff_real_b[36][7] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[36][7] = 32'h00000000;  // 0.0j

    idx_b[36][7] = 4'd10;

    // b37 computation

    coeff_real_b[37][0] = 32'h00000000;  // 0.0

    coeff_imag_b[37][0] = 32'h00008000;  // 0.5j

    idx_b[37][0] = 4'd1;
    coeff_real_b[37][1] = 32'h00000000;  // 0.0

    coeff_imag_b[37][1] = 32'h00008000;  // 0.5j

    idx_b[37][1] = 4'd2;
    coeff_real_b[37][2] = 32'h00000000;  // 0.0

    coeff_imag_b[37][2] = 32'h00008000;  // 0.5j

    idx_b[37][2] = 4'd3;
    coeff_real_b[37][3] = 32'h00000000;  // 0.0

    coeff_imag_b[37][3] = 32'hFFFF8000;  // -0.5j

    idx_b[37][3] = 4'd4;
    coeff_real_b[37][4] = 32'h00000000;  // 0.0

    coeff_imag_b[37][4] = 32'h00008000;  // 0.5j

    idx_b[37][4] = 4'd6;
    coeff_real_b[37][5] = 32'h00000000;  // 0.0

    coeff_imag_b[37][5] = 32'h00008000;  // 0.5j

    idx_b[37][5] = 4'd7;
    coeff_real_b[37][6] = 32'h00000000;  // 0.0

    coeff_imag_b[37][6] = 32'hFFFF8000;  // -0.5j

    idx_b[37][6] = 4'd8;
    coeff_real_b[37][7] = 32'h00000000;  // 0.0

    coeff_imag_b[37][7] = 32'h00008000;  // 0.5j

    idx_b[37][7] = 4'd10;

    // b38 computation

    coeff_real_b[38][0] = 32'h00000000;  // 0.0

    coeff_imag_b[38][0] = 32'h00008000;  // 0.5j

    idx_b[38][0] = 4'd0;
    coeff_real_b[38][1] = 32'h00000000;  // 0.0

    coeff_imag_b[38][1] = 32'hFFFF8000;  // -0.5j

    idx_b[38][1] = 4'd4;
    coeff_real_b[38][2] = 32'h00000000;  // 0.0

    coeff_imag_b[38][2] = 32'hFFFF8000;  // -0.5j

    idx_b[38][2] = 4'd8;
    coeff_real_b[38][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[38][3] = 32'h00000000;  // 0.0j

    idx_b[38][3] = 4'd12;

    // b39 computation

    coeff_real_b[39][0] = 32'h00000000;  // 0.0

    coeff_imag_b[39][0] = 32'hFFFF8000;  // -0.5j

    idx_b[39][0] = 4'd0;
    coeff_real_b[39][1] = 32'h00000000;  // 0.0

    coeff_imag_b[39][1] = 32'h00008000;  // 0.5j

    idx_b[39][1] = 4'd3;
    coeff_real_b[39][2] = 32'h00000000;  // 0.0

    coeff_imag_b[39][2] = 32'h00008000;  // 0.5j

    idx_b[39][2] = 4'd5;
    coeff_real_b[39][3] = 32'h00000000;  // 0.0

    coeff_imag_b[39][3] = 32'h00008000;  // 0.5j

    idx_b[39][3] = 4'd7;
    coeff_real_b[39][4] = 32'h00000000;  // 0.0

    coeff_imag_b[39][4] = 32'h00008000;  // 0.5j

    idx_b[39][4] = 4'd9;
    coeff_real_b[39][5] = 32'h00000000;  // 0.0

    coeff_imag_b[39][5] = 32'h00008000;  // 0.5j

    idx_b[39][5] = 4'd11;
    coeff_real_b[39][6] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[39][6] = 32'h00000000;  // 0.0j

    idx_b[39][6] = 4'd12;
    coeff_real_b[39][7] = 32'h00008000;  // 0.5

    coeff_imag_b[39][7] = 32'h00000000;  // 0.0j

    idx_b[39][7] = 4'd15;

    // b40 computation

    coeff_real_b[40][0] = 32'h00000000;  // 0.0

    coeff_imag_b[40][0] = 32'h00008000;  // 0.5j

    idx_b[40][0] = 4'd1;
    coeff_real_b[40][1] = 32'h00000000;  // 0.0

    coeff_imag_b[40][1] = 32'h00008000;  // 0.5j

    idx_b[40][1] = 4'd2;
    coeff_real_b[40][2] = 32'h00000000;  // 0.0

    coeff_imag_b[40][2] = 32'h00008000;  // 0.5j

    idx_b[40][2] = 4'd5;
    coeff_real_b[40][3] = 32'h00000000;  // 0.0

    coeff_imag_b[40][3] = 32'h00008000;  // 0.5j

    idx_b[40][3] = 4'd6;
    coeff_real_b[40][4] = 32'h00000000;  // 0.0

    coeff_imag_b[40][4] = 32'hFFFF8000;  // -0.5j

    idx_b[40][4] = 4'd9;
    coeff_real_b[40][5] = 32'h00000000;  // 0.0

    coeff_imag_b[40][5] = 32'hFFFF8000;  // -0.5j

    idx_b[40][5] = 4'd10;
    coeff_real_b[40][6] = 32'h00008000;  // 0.5

    coeff_imag_b[40][6] = 32'h00000000;  // 0.0j

    idx_b[40][6] = 4'd13;
    coeff_real_b[40][7] = 32'h00008000;  // 0.5

    coeff_imag_b[40][7] = 32'h00000000;  // 0.0j

    idx_b[40][7] = 4'd14;

    // b41 computation

    coeff_real_b[41][0] = 32'h00008000;  // 0.5

    coeff_imag_b[41][0] = 32'h00000000;  // 0.0j

    idx_b[41][0] = 4'd0;
    coeff_real_b[41][1] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[41][1] = 32'h00000000;  // 0.0j

    idx_b[41][1] = 4'd3;
    coeff_real_b[41][2] = 32'h00008000;  // 0.5

    coeff_imag_b[41][2] = 32'h00000000;  // 0.0j

    idx_b[41][2] = 4'd4;
    coeff_real_b[41][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[41][3] = 32'h00000000;  // 0.0j

    idx_b[41][3] = 4'd7;
    coeff_real_b[41][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[41][4] = 32'h00000000;  // 0.0j

    idx_b[41][4] = 4'd8;
    coeff_real_b[41][5] = 32'h00008000;  // 0.5

    coeff_imag_b[41][5] = 32'h00000000;  // 0.0j

    idx_b[41][5] = 4'd11;
    coeff_real_b[41][6] = 32'h00000000;  // 0.0

    coeff_imag_b[41][6] = 32'h00008000;  // 0.5j

    idx_b[41][6] = 4'd12;
    coeff_real_b[41][7] = 32'h00000000;  // 0.0

    coeff_imag_b[41][7] = 32'hFFFF8000;  // -0.5j

    idx_b[41][7] = 4'd15;

    // b42 computation

    coeff_real_b[42][0] = 32'h00000000;  // 0.0

    coeff_imag_b[42][0] = 32'h00008000;  // 0.5j

    idx_b[42][0] = 4'd0;
    coeff_real_b[42][1] = 32'h00000000;  // 0.0

    coeff_imag_b[42][1] = 32'hFFFF8000;  // -0.5j

    idx_b[42][1] = 4'd4;
    coeff_real_b[42][2] = 32'h00000000;  // 0.0

    coeff_imag_b[42][2] = 32'h00008000;  // 0.5j

    idx_b[42][2] = 4'd8;
    coeff_real_b[42][3] = 32'h00008000;  // 0.5

    coeff_imag_b[42][3] = 32'h00000000;  // 0.0j

    idx_b[42][3] = 4'd12;

    // b43 computation

    coeff_real_b[43][0] = 32'h00008000;  // 0.5

    coeff_imag_b[43][0] = 32'h00000000;  // 0.0j

    idx_b[43][0] = 4'd0;
    coeff_real_b[43][1] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[43][1] = 32'h00000000;  // 0.0j

    idx_b[43][1] = 4'd2;
    coeff_real_b[43][2] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[43][2] = 32'h00000000;  // 0.0j

    idx_b[43][2] = 4'd3;
    coeff_real_b[43][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[43][3] = 32'h00000000;  // 0.0j

    idx_b[43][3] = 4'd5;
    coeff_real_b[43][4] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[43][4] = 32'h00000000;  // 0.0j

    idx_b[43][4] = 4'd6;
    coeff_real_b[43][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[43][5] = 32'h00000000;  // 0.0j

    idx_b[43][5] = 4'd7;
    coeff_real_b[43][6] = 32'h00008000;  // 0.5

    coeff_imag_b[43][6] = 32'h00000000;  // 0.0j

    idx_b[43][6] = 4'd9;
    coeff_real_b[43][7] = 32'h00008000;  // 0.5

    coeff_imag_b[43][7] = 32'h00000000;  // 0.0j

    idx_b[43][7] = 4'd10;

    // b44 computation

    coeff_real_b[44][0] = 32'h00000000;  // 0.0

    coeff_imag_b[44][0] = 32'hFFFF8000;  // -0.5j

    idx_b[44][0] = 4'd0;
    coeff_real_b[44][1] = 32'h00000000;  // 0.0

    coeff_imag_b[44][1] = 32'h00008000;  // 0.5j

    idx_b[44][1] = 4'd4;
    coeff_real_b[44][2] = 32'h00000000;  // 0.0

    coeff_imag_b[44][2] = 32'hFFFF8000;  // -0.5j

    idx_b[44][2] = 4'd8;
    coeff_real_b[44][3] = 32'h00008000;  // 0.5

    coeff_imag_b[44][3] = 32'h00000000;  // 0.0j

    idx_b[44][3] = 4'd12;

    // b45 computation

    coeff_real_b[45][0] = 32'h00000000;  // 0.0

    coeff_imag_b[45][0] = 32'hFFFF8000;  // -0.5j

    idx_b[45][0] = 4'd1;
    coeff_real_b[45][1] = 32'h00000000;  // 0.0

    coeff_imag_b[45][1] = 32'hFFFF8000;  // -0.5j

    idx_b[45][1] = 4'd2;
    coeff_real_b[45][2] = 32'h00000000;  // 0.0

    coeff_imag_b[45][2] = 32'hFFFF8000;  // -0.5j

    idx_b[45][2] = 4'd3;
    coeff_real_b[45][3] = 32'h00000000;  // 0.0

    coeff_imag_b[45][3] = 32'h00008000;  // 0.5j

    idx_b[45][3] = 4'd5;
    coeff_real_b[45][4] = 32'h00000000;  // 0.0

    coeff_imag_b[45][4] = 32'h00008000;  // 0.5j

    idx_b[45][4] = 4'd6;
    coeff_real_b[45][5] = 32'h00000000;  // 0.0

    coeff_imag_b[45][5] = 32'h00008000;  // 0.5j

    idx_b[45][5] = 4'd7;
    coeff_real_b[45][6] = 32'h00000000;  // 0.0

    coeff_imag_b[45][6] = 32'hFFFF8000;  // -0.5j

    idx_b[45][6] = 4'd9;
    coeff_real_b[45][7] = 32'h00000000;  // 0.0

    coeff_imag_b[45][7] = 32'hFFFF8000;  // -0.5j

    idx_b[45][7] = 4'd10;

    // b46 computation

    coeff_real_b[46][0] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[46][0] = 32'h00000000;  // 0.0j

    idx_b[46][0] = 4'd0;
    coeff_real_b[46][1] = 32'h00008000;  // 0.5

    coeff_imag_b[46][1] = 32'h00000000;  // 0.0j

    idx_b[46][1] = 4'd2;
    coeff_real_b[46][2] = 32'h00008000;  // 0.5

    coeff_imag_b[46][2] = 32'h00000000;  // 0.0j

    idx_b[46][2] = 4'd4;
    coeff_real_b[46][3] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[46][3] = 32'h00000000;  // 0.0j

    idx_b[46][3] = 4'd6;
    coeff_real_b[46][4] = 32'h00008000;  // 0.5

    coeff_imag_b[46][4] = 32'h00000000;  // 0.0j

    idx_b[46][4] = 4'd8;
    coeff_real_b[46][5] = 32'hFFFF8000;  // -0.5

    coeff_imag_b[46][5] = 32'h00000000;  // 0.0j

    idx_b[46][5] = 4'd10;
    coeff_real_b[46][6] = 32'h00000000;  // 0.0

    coeff_imag_b[46][6] = 32'h00008000;  // 0.5j

    idx_b[46][6] = 4'd12;
    coeff_real_b[46][7] = 32'h00000000;  // 0.0

    coeff_imag_b[46][7] = 32'hFFFF8000;  // -0.5j

    idx_b[46][7] = 4'd14;

    // b47 computation

    coeff_real_b[47][0] = 32'h00008000;  // 0.5

    coeff_imag_b[47][0] = 32'h00000000;  // 0.0j

    idx_b[47][0] = 4'd0;
    coeff_real_b[47][1] = 32'h00008000;  // 0.5

    coeff_imag_b[47][1] = 32'h00000000;  // 0.0j

    idx_b[47][1] = 4'd5;
    coeff_real_b[47][2] = 32'h00008000;  // 0.5

    coeff_imag_b[47][2] = 32'h00000000;  // 0.0j

    idx_b[47][2] = 4'd9;
    coeff_real_b[47][3] = 32'h00000000;  // 0.0

    coeff_imag_b[47][3] = 32'h00008000;  // 0.5j

    idx_b[47][3] = 4'd12;

    // C coefficients (m array indices)

    // C[0,0] computation

    idx_m[0][0] = 8'd0;
    idx_m[0][1] = 8'd1;
    idx_m[0][2] = 8'd5;
    idx_m[0][3] = 8'd8;
    idx_m[0][4] = 8'd9;
    idx_m[0][5] = 8'd11;
    idx_m[0][6] = 8'd14;
    idx_m[0][7] = 8'd15;

    // C[0,1] computation

    idx_m[1][0] = 8'd0;
    idx_m[1][1] = 8'd2;
    idx_m[1][2] = 8'd3;
    idx_m[1][3] = 8'd5;
    idx_m[1][4] = 8'd6;
    idx_m[1][5] = 8'd8;
    idx_m[1][6] = 8'd11;
    idx_m[1][7] = 8'd12;

    // C[0,2] computation

    idx_m[2][0] = 8'd2;
    idx_m[2][1] = 8'd3;
    idx_m[2][2] = 8'd5;
    idx_m[2][3] = 8'd8;
    idx_m[2][4] = 8'd11;
    idx_m[2][5] = 8'd12;
    idx_m[2][6] = 8'd13;
    idx_m[2][7] = 8'd14;

    // C[0,3] computation

    idx_m[3][0] = 8'd0;
    idx_m[3][1] = 8'd1;
    idx_m[3][2] = 8'd3;
    idx_m[3][3] = 8'd4;
    idx_m[3][4] = 8'd6;
    idx_m[3][5] = 8'd7;
    idx_m[3][6] = 8'd8;
    idx_m[3][7] = 8'd9;

    // C[1,0] computation

    idx_m[4][0] = 8'd0;
    idx_m[4][1] = 8'd1;
    idx_m[4][2] = 8'd5;
    idx_m[4][3] = 8'd8;
    idx_m[4][4] = 8'd9;
    idx_m[4][5] = 8'd11;
    idx_m[4][6] = 8'd14;
    idx_m[4][7] = 8'd15;

    // C[1,1] computation

    idx_m[5][0] = 8'd0;
    idx_m[5][1] = 8'd2;
    idx_m[5][2] = 8'd3;
    idx_m[5][3] = 8'd5;
    idx_m[5][4] = 8'd6;
    idx_m[5][5] = 8'd8;
    idx_m[5][6] = 8'd11;
    idx_m[5][7] = 8'd12;

    // C[1,2] computation

    idx_m[6][0] = 8'd2;
    idx_m[6][1] = 8'd3;
    idx_m[6][2] = 8'd5;
    idx_m[6][3] = 8'd8;
    idx_m[6][4] = 8'd11;
    idx_m[6][5] = 8'd12;
    idx_m[6][6] = 8'd13;
    idx_m[6][7] = 8'd14;

    // C[1,3] computation

    idx_m[7][0] = 8'd0;
    idx_m[7][1] = 8'd1;
    idx_m[7][2] = 8'd3;
    idx_m[7][3] = 8'd4;
    idx_m[7][4] = 8'd6;
    idx_m[7][5] = 8'd7;
    idx_m[7][6] = 8'd8;
    idx_m[7][7] = 8'd9;

    // C[2,0] computation

    idx_m[8][0] = 8'd0;
    idx_m[8][1] = 8'd1;
    idx_m[8][2] = 8'd5;
    idx_m[8][3] = 8'd8;
    idx_m[8][4] = 8'd9;
    idx_m[8][5] = 8'd11;
    idx_m[8][6] = 8'd14;
    idx_m[8][7] = 8'd15;

    // C[2,1] computation

    idx_m[9][0] = 8'd0;
    idx_m[9][1] = 8'd2;
    idx_m[9][2] = 8'd3;
    idx_m[9][3] = 8'd5;
    idx_m[9][4] = 8'd6;
    idx_m[9][5] = 8'd8;
    idx_m[9][6] = 8'd11;
    idx_m[9][7] = 8'd12;

    // C[2,2] computation

    idx_m[10][0] = 8'd2;
    idx_m[10][1] = 8'd3;
    idx_m[10][2] = 8'd5;
    idx_m[10][3] = 8'd8;
    idx_m[10][4] = 8'd11;
    idx_m[10][5] = 8'd12;
    idx_m[10][6] = 8'd13;
    idx_m[10][7] = 8'd14;

    // C[2,3] computation

    idx_m[11][0] = 8'd0;
    idx_m[11][1] = 8'd1;
    idx_m[11][2] = 8'd3;
    idx_m[11][3] = 8'd4;
    idx_m[11][4] = 8'd6;
    idx_m[11][5] = 8'd7;
    idx_m[11][6] = 8'd8;
    idx_m[11][7] = 8'd9;

    // C[3,0] computation

    idx_m[12][0] = 8'd0;
    idx_m[12][1] = 8'd1;
    idx_m[12][2] = 8'd5;
    idx_m[12][3] = 8'd8;
    idx_m[12][4] = 8'd9;
    idx_m[12][5] = 8'd11;
    idx_m[12][6] = 8'd14;
    idx_m[12][7] = 8'd15;

    // C[3,1] computation

    idx_m[13][0] = 8'd0;
    idx_m[13][1] = 8'd2;
    idx_m[13][2] = 8'd3;
    idx_m[13][3] = 8'd5;
    idx_m[13][4] = 8'd6;
    idx_m[13][5] = 8'd8;
    idx_m[13][6] = 8'd11;
    idx_m[13][7] = 8'd12;

    // C[3,2] computation

    idx_m[14][0] = 8'd2;
    idx_m[14][1] = 8'd3;
    idx_m[14][2] = 8'd5;
    idx_m[14][3] = 8'd8;
    idx_m[14][4] = 8'd11;
    idx_m[14][5] = 8'd12;
    idx_m[14][6] = 8'd13;
    idx_m[14][7] = 8'd14;

    // C[3,3] computation

    idx_m[15][0] = 8'd0;
    idx_m[15][1] = 8'd1;
    idx_m[15][2] = 8'd3;
    idx_m[15][3] = 8'd4;
    idx_m[15][4] = 8'd6;
    idx_m[15][5] = 8'd7;
    idx_m[15][6] = 8'd8;
    idx_m[15][7] = 8'd9;


  end

  // State machine


  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      compute_index <= 0;
      done <= 0;
      data_out <= 32'h0;

      // Initialize memory arrays


      for (i = 0; i < 48; i = i + 1) begin
        a[i] <= 64'h0;
        b[i] <= 64'h0;
        m[i] <= 64'h0;
      end

      for (i = 0; i < 16; i = i + 1) begin
        C[i] <= 32'h0;
        A_reg[i] <= 32'h0;
        B_reg[i] <= 32'h0;
      end

      temp_accum <= 64'h0;
      temp_sum   <= 32'h0;
    end else begin
      state <= next_state;  // CRITICAL: Update state register



      case (state)
        IDLE: begin
          compute_index <= 0;
          done <= 0;
        end

        LOAD: begin
          if (load_en && addr_in < 32) begin
            if (addr_in < 16) A_reg[addr_in[3:0]] <= data_in;
            else B_reg[addr_in[3:0]] <= data_in;
          end
        end

        COMPUTE_A: begin
          if (compute_index < 48) begin
            temp_accum = 64'h0;
            for (i = 0; i < 8; i = i + 1) begin
              temp_accum = complex_add_coeff(
                coeff_real_a[compute_index][i],
                coeff_imag_a[compute_index][i],
                A_reg[idx_a[compute_index][i]],
                temp_accum
              );
            end
            a[compute_index] <= temp_accum;
            compute_index <= compute_index + 1;
          end
        end

        COMPUTE_B: begin
          if (compute_index < 48) begin
            temp_accum = 64'h0;
            for (i = 0; i < 8; i = i + 1) begin
              temp_accum = complex_add_coeff(
                coeff_real_b[compute_index][i],
                coeff_imag_b[compute_index][i],
                B_reg[idx_b[compute_index][i]],
                temp_accum
              );
            end
            b[compute_index] <= temp_accum;
            compute_index <= compute_index + 1;
          end
        end

        COMPUTE_M: begin
          if (compute_index < 48) begin
            m[compute_index] <= complex_mult(a[compute_index], b[compute_index]);
            compute_index <= compute_index + 1;
          end
        end

        COMPUTE_C: begin
          if (compute_index < 16) begin
            temp_sum = 32'h0;
            for (i = 0; i < 8; i = i + 1) begin
              temp_sum = temp_sum + $signed(m[idx_m[compute_index][i]][63:32]);
            end
            C[compute_index] <= temp_sum;
            compute_index <= compute_index + 1;
          end
        end

        DONE: begin
          done <= 1;
          compute_index <= 0;
        end
      endcase

      // Handle read operations


      if (read_en && addr_in < 16) begin
        data_out <= C[addr_in[3:0]];
      end
    end
  end

  // Next state logic


  always @(*) begin
    case (state)
      IDLE: next_state = start ? LOAD : IDLE;
      LOAD: next_state = load_en ? LOAD : COMPUTE_A;
      COMPUTE_A: next_state = (compute_index >= 47) ? COMPUTE_B : COMPUTE_A;
      COMPUTE_B: next_state = (compute_index >= 47) ? COMPUTE_M : COMPUTE_B;
      COMPUTE_M: next_state = (compute_index >= 47) ? COMPUTE_C : COMPUTE_M;
      COMPUTE_C: next_state = (compute_index >= 15) ? DONE : COMPUTE_C;
      DONE: next_state = start ? LOAD : (start ? IDLE : DONE);
      default: next_state = IDLE;
    endcase
  end

endmodule
