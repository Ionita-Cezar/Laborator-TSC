/***********************************************************************
 * A SystemVerilog testbench for an instruction register.
 * The course labs will convert this to an object-oriented testbench
 * with constrained random test generation, functional coverage, and
 * a scoreboard for self-verification.
 **********************************************************************/

module instr_register_test
  import instr_register_pkg::*;  // user-defined types are defined in instr_register_pkg.sv
  (input  logic          clk,
   output logic          load_en,
   output logic          reset_n,
   output operand_t      operand_a,
   output operand_t      operand_b,
   output opcode_t       opcode,
   output address_t      write_pointer,
   output address_t      read_pointer,
   input  instruction_t  instruction_word
  );

  timeunit 1ns/1ns;

  parameter RD_NR = 40;
  parameter WR_NT = 40;
  parameter write_order = 0; // 0 - incremental, 1 - random, 2 - decremental
  parameter read_order = 0;  // 0 - incremental, 1 - random, 2 - decremental
  parameter CASE_NAME;

  int seed = 555;

  instruction_t save_data [0:31];
  
  int write_order_val = 0;
  int read_order_val = 0;

  int failed_tests = 0;
  int passed_tests = 0;

  initial begin
    $display("\n\n***********************************************************");
    $display(    "***  THIS IS A SELF-CHECKING TESTBENCH.  YOU DON'T      ***");
    $display(    "***  NEED TO VISUALLY VERIFY THAT THE OUTPUT VALUES     ***");
    $display(    "***  MATCH THE INPUT VALUES FOR EACH REGISTER LOCATION  ***");
    $display(    "***********************************************************");

    $display("\nReseting the instruction register...");
    write_pointer  = 5'h00;         // initialize write pointer
    read_pointer   = 5'h1F;         // initialize read pointer
    load_en        = 1'b0;          // initialize load control line
    reset_n       <= 1'b0;          // assert reset_n (active low)
    repeat (2) @(posedge clk) ;     // hold in reset for 2 clock cycles
    reset_n        = 1'b1;          // deassert reset_n (active low)

    $display("\nWriting values to register stack...");
    @(posedge clk) load_en = 1'b1;  // enable writing to register
    // repeat (3) begin - 11/03/2024 - IC
    repeat (WR_NT) begin
      @(posedge clk) randomize_transaction;
      // @(negedge clk) print_transaction;
      save_test_data;
    end
    @(posedge clk) load_en = 1'b0;  // turn-off writing to register

    // read back and display same three register locations
    $display("\nReading back the same register locations written...");
    // for (int i=0; i<=2; i++) begin - 11/03/2024 - IC
    for (int i=0; i<=RD_NR; i++) begin
      // later labs will replace this loop with iterating through a
      // scoreboard to determine which addresses were written and
      // the expected values to be read back

      // @(posedge clk) read_pointer = i; - 25/03/2024 - IC
      case (read_order)
        0: @(posedge clk) read_pointer = read_order_val++;
        1: @(posedge clk) read_pointer = $unsigned($random) % 32;
        2: @(posedge clk) read_pointer = 31 - read_order_val++;
      endcase
      @(negedge clk) print_results;
      check_result;
    end

    $display("\nTotal passed tests: %d", passed_tests);
    $display("\nTotal failed tests: %d", failed_tests);

    @(posedge clk);
    report;

    @(posedge clk) ;
    $display("\n***********************************************************");
    $display(  "***  THIS IS A SELF-CHECKING TESTBENCH.  YOU DON'T      ***");
    $display(  "***  NEED TO VISUALLY VERIFY THAT THE OUTPUT VALUES     ***");
    $display(  "***  MATCH THE INPUT VALUES FOR EACH REGISTER LOCATION  ***");
    $display(  "***********************************************************\n");
    $finish;
  end

  function void randomize_transaction;
    // A later lab will replace this function with SystemVerilog
    // constrained random values
    //
    // The stactic temp variable is required in order to write to fixed
    // addresses of 0, 1 and 2.  This will be replaceed with randomizeed
    // write_pointer values in a later lab
    //
    static int temp = 0;
    operand_a     <= $random(seed)%16;                 // between -15 and 15
    operand_b     <= $unsigned($random)%16;            // between 0 and 15
    opcode        <= opcode_t'($unsigned($random)%8);  // between 0 and 7, cast to opcode_t type
    case (write_order)
      0: write_pointer <= write_order_val++;
      1: write_pointer <= $unsigned($random) % 32;
      2: write_pointer <= 31 - write_order_val++;
    endcase
    //write_pointer <= temp++; - 25.03.2024 - IC
  endfunction: randomize_transaction

  function void print_transaction;
    $display("Writing to register location %0d: ", write_pointer);
    $display("  opcode = %0d (%s)", opcode, opcode.name);
    $display("  operand_a = %0d",   operand_a);
    $display("  operand_b = %0d\n", operand_b);
  endfunction: print_transaction

  function void save_test_data;
    result_t local_res;
      case (opcode)     // Perform operation based on opcode
        ZERO:     local_res = {64{1'b0}};
        PASSA:    local_res = operand_a;
        PASSB:    local_res = operand_b;
        ADD:      local_res = operand_a + operand_b;
        SUB:      local_res = operand_a - operand_b;
        MULT:     local_res = operand_a * operand_b;
        DIV:      local_res = operand_b == 0 ? 0 : operand_a / operand_b;
        MOD:      local_res = operand_b == 0 ? 0 : operand_a % operand_b;
      endcase

      save_data[write_pointer] = '{opcode, operand_a, operand_b, local_res};

  endfunction: save_test_data

  function void print_results;
    $display("Read from register location %0d: ", read_pointer);
    $display("  opcode = %0d (%s)", instruction_word.opc, instruction_word.opc.name);
    $display("  operand_a = %0d",   instruction_word.op_a);
    $display("  operand_b = %0d\n", instruction_word.op_b);
    $display("  result = %0d\n",    instruction_word.res);
  endfunction: print_results

  function void check_result;
    if (save_data[read_pointer].opc != instruction_word.opc ||
        save_data[read_pointer].op_a != instruction_word.op_a ||
        save_data[read_pointer].op_b != instruction_word.op_b ||
        save_data[read_pointer].res != instruction_word.res)
    begin
      $display("Error: Test failed at register location %0d", read_pointer);
      failed_tests++;
    end
    else
    begin
      passed_tests++;
    end
  endfunction: check_result

  function void report;
    int file;
    file = $fopen("../reports/regression_status.txt", "a");
    if(failed_tests != 0) begin
      $fwrite(file, "Case %s: failed\n", CASE_NAME);
    end else begin
    $fwrite(file, "Case %s: passed\ns", CASE_NAME);
  end
  $fclose(file);
  endfunction: report

endmodule: instr_register_test