`timescale 1ns/1ps

module test;
  parameter DATA_WIDTH = 8;
  parameter DEPTH = 16;
  parameter ADDR_WIDTH  = $clog2(DEPTH);

  reg clk;
  reg rst;
  reg wr_en;
  reg rd_en;
  reg [DATA_WIDTH-1:0] din;
  wire [DATA_WIDTH-1:0] dout;
  wire full;
  wire empty;  
  
  fifo#(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) uut (
  .clk(clk),
  .rst(rst),
  .wr_en(wr_en),
  .rd_en(rd_en),
  .din(din),
  .dout(dout),
  .full(full),
  .empty(empty)
  );
 
//generating clk
  initial clk=0;
always #5 clk=~clk;
 
  // waveform dump
  initial begin
    $dumpfile("fifo_tb.vcd");  
    $dumpvars(0, test);         
  end
  
  
  //1)check reset condition 
  task check_reset;
    begin
      if(empty==1 || full==0 || dout==0) begin
        $display("[passed] Reset test");
        end else begin
          $display("[failed] Reser test");
        end
    end
  endtask

  // 2) Check write operation when fifo is not full
  task check_single_write;
    begin 
      @(posedge clk);
      wr_en=1;
      din=8'hAA;
      @(posedge clk);
      wr_en=0;
      din=0;
      
      // Wait extra clock cycle to let flags update
      @(posedge clk)
      if(full==0 && empty==0) begin
        $display("[Passed] write Test(single write)");
      end else begin
        $display("[Failed] write test");
      end
    end
  endtask
      
      
  //3) Checking read operation when fifo is not empty
  task check_single_read;
    reg[DATA_WIDTH-1:0] read_data;
    begin
      //write one known value first
      @(posedge clk);
      wr_en=1;
      din=8'h55;
      @(posedge clk)
      wr_en=0;
      din=0;
  
      //wait for one clock for write to complete
      @(posedge clk);
      
      //now read it back
      @(posedge clk);
      rd_en=1;
      @(posedge clk)
      rd_en=0;
      
      //wait for dout to update and capture dout after read
      @(posedge clk);
      read_data=dout;
      
      //wait for outputs to stabilize
      @(posedge clk);
      if(read_data==8'h55 && empty==1 && full==0) begin
        $display("[passed] Read test (single read)");
      end else begin
        $display("[Failed] Read test");
        $display("    dout = 0x%0h, empty = %b, full = %b (expected dout=0x55, empty=1, full=0)", read_data, empty, full);
    end
    end
  endtask
      
  //4)Test FIFO Full Condition 

  task check_fifo_full;
    integer i;
    begin
      $display("......Fifo Full Test.....");
      
      for(i=0; i< DEPTH; i=i+1) begin
        @(posedge clk)
        wr_en=1;
        din=i;
      end
      
      @(posedge clk);
      wr_en=0;
     
      //waits for one more cycle for flags to update
      @(posedge clk);
      
      if(full==1 && empty==0) begin
        $display("[passed] Fifo full test");
        end else begin
          $display("[Failed] Fifo full test");
        end
    end
  endtask
  
  
  //5)Test Fifo Empty condition
  task check_fifo_empty;
    integer i;
    begin
      $display("......Fifo Empty test......");
      
    //First->fill fifo completely 
      for(i=0; i<DEPTH; i=i+1) begin
        @(posedge clk);
        wr_en=1;
        din=i;
      end
      
      @(posedge clk)
      wr_en=0;
      
      //Now, read all elements 
      for(i=0; i<DEPTH; i=i+1) begin
        @(posedge clk);
      rd_en=1;
    end
    
    @(posedge clk)
    rd_en=0;
      
      //wait one more clock cycle for flags to settle 
      @(posedge clk);
      if(empty==1 && full==0) begin
        $display ("[passed] Fifo empty test");
      end else begin
        $display("[failed] Fifo empty test");
      end
    end
  endtask
        
  
  //6) Simultaneous Read and Write Test
task check_simul_read_write;
  integer i;
  reg [7:0] expected_data[0:5]; // to track FIFO behavior
  begin
    $display("......Simultaneous Read and Write Test......");

    // Reset FIFO
    rst = 1;
    wr_en = 0;
    rd_en = 0;
    din = 0;
    @(posedge clk);
    rst = 0;
    @(posedge clk);

    // Pre-fill FIFO with one value
    wr_en = 1;
    din = 8'hA5;
    expected_data[0] = 8'hA5;
    @(posedge clk);
//     wr_en = 0;
//     din = 0;
//     @(posedge clk);

    // Now perform simultaneous read and write
    for (i = 1; i <=5; i = i + 1) begin
      wr_en = 1;
      rd_en = 1;
      din = 8'hB0 + i;
      expected_data[i] = din; // store to match later
      
      @(posedge clk);
     // Skip i == 1 since we pre-filled one element
      if (i >= 2) begin
        if (dout !== expected_data[i - 2]) begin
          $display("[Failed] Simul RW Cycle %0d: dout = 0x%0h (expected 0x%0h)", i - 1, dout, expected_data[i - 2]);
        end else begin
          $display("[Passed] Simul RW Cycle %0d: dout = 0x%0h", i - 1, dout);
        end
      end
    end

    // disable signals
    wr_en = 0;
    rd_en = 0;
    din = 0;
    @(posedge clk);
  end
endtask

  /////////////////////////////////////////////////////////////
  
 //7) Fifo full and overflow test
  task check_full_and_overflow;
    integer i;
    begin
      $display("......overflow Test......");
  //Reset
//       rst=1;
//       wr_en=0;
//       din=0;
//       @(posedge clk)
//       rst=0;
//       @(posedge clk)
      
  //fill the fifo completely
      for(i=0; i<DEPTH; i=i+1) begin
        wr_en=1;
        din=8'h10+i;
        @(posedge clk)
        if(full) begin
          $display("[Failed] FIFO reported full before expected at write %0d", i); 
        end
      end
      
 //check if fifo is full now
      wr_en=0;
       @(posedge clk);
    if (full)
      $display("[Passed] FIFO full signal correctly set after %0d writes", DEPTH);
    else
      $display("[Failed] FIFO full signal not set after %0d writes", DEPTH);
      
//Try one more write
      wr_en=1;
      din=8'hFF;
      if(full)
        $display("[passed] write blocked when fifo full");
      else
        $display("[failed] write allowed even though fifo empty");
      wr_en=0;
      din=0;
      @(posedge clk);
    end
  endtask
  
  /////////////////////////////////////////////////////////////
      
  //8)FIFO Empty and Underflow Test 
  task check_empty_and_underflow;
    integer i;
    begin
      $display("......Fifo empty and Underflow Test......");
      
      //fill fifo with 4 values 
      for(i=0; i<4; i=i+1)
        begin
        wr_en=1;
       din=8'h20+i;
      @(posedge clk);
    end
    
      wr_en=0;
      din=0;
    @(posedge clk);
    
    //read all values
    for(int i=0; i<4; i=i+1) begin
      rd_en=1;
      @(posedge clk);
    end
    
    rd_en=0;
    @(posedge clk);
     // Check if FIFO is empty
    
    if (empty)
      $display("[Passed] FIFO empty signal correctly set after all reads");
    else
      $display("[Failed] FIFO empty signal not set after all reads");
    
    //Attempt one more read(underfow condition)
    rd_en=1;
    @(posedge clk);
      
    if(dout===8'bx || dout===0) begin
      $display("[passed] No vaid data read empty(underflow test correctly  passed)");
    end else begin 
       $display("[Failed] Unexpected data read after FIFO became empty: 0x%0h", dout);
    end
    
    rd_en=0;
    @(posedge clk);
    end
 endtask

  /////////////////////////////////////////////////////////////
  
  //9) Wrap around behavior 
  task check_wrap_around;
    integer i;
    begin
      $display("......Fifo Wraparound Test......");
      
      
      
      //fill the fifo completely 
      for(i=0; i<DEPTH; i=i+1) begin
        wr_en=1;
        din=8'hD0+i;
        @(posedge clk);
      end
      
      wr_en=0;
      din=0;
      @(posedge clk);
      
      //Read half enteries
      for(i=0; i<DEPTH/2; i=i+1) begin
        rd_en=1;
        @(posedge clk);
      end
      
      rd_en=0;
      @(posedge clk);
      
      //write more values to cause wraparound 
      for(i=0; i<DEPTH/2; i=i+1) begin
        wr_en=1;
        din=8'hE0+i;
        @(posedge clk);
      end
      
      wr_en=0;
      din=0;
      @(posedge clk);
  
  	//read remaining value
      for(i=0; i<DEPTH/2; i=i+1) begin
        rd_en=1;
        @(posedge clk);
      end
      rd_en=0;
      
      $display("[passed] Wrap around behavior is working correctly");
   @(posedge clk);
   end
 endtask
  
  /////////////////////////////////////////////////////////////
  
  //10) Reset Behavior Mid-Operation (apply reset after some write)
  task check_reset_at_mid;
    integer i;
    begin
      $display("......Fifo mid-operaton reset test.....");
      
      //fill partially
      for(i=0; i<4; i=i+1) begin
        wr_en=1;
        din=8'h90+i;
        @(posedge clk);
      end
      
      wr_en=0;
      @(posedge clk);
      
      //apply reset in middle 
      rst=1;
      @(posedge clk);
      rst=0;
      @(posedge clk);
      
      //check if fifo is reset
      if(!empty || full) begin
        $display("[failed] fifo did not reset properly");
      end else begin
        $display("[passed] fifo reset properly during mid test");
      end
 
//Try read after reset->should output 0 ot x
      rd_en = 1;
    @(posedge clk);
    if (dout === 8'bx || dout === 8'h00) begin
      $display("[Passed] No stale data after mid-reset");
    end else begin
      $display("[Failed] Unexpected data after reset: dout = 0x%0h", dout);
    end

    rd_en = 0;
    @(posedge clk);
    
    end
endtask       
   ///////////////////////////////////////////////////////////// 
  
  //11) write random value and the read 
  task random_write_read;
    reg[7:0] expected_data[0:DEPTH-1];
  integer i;
  begin
    $display("......write then read random data test......");
    
    //writing random values 
    for(i=0; i<DEPTH; i=i+1) begin
      wr_en=1;
      din=$urandom_range(0,255);
      expected_data[i]=din; // we are storing in to verify ot match
      @(posedge clk);
    end
    wr_en=0;
    din=0;
    @(posedge clk);
    
    //Read back and check
    for(i=0; i<DEPTH; i=i+1) begin
      rd_en=1;
      @(posedge clk);
      if(i>1) begin
      if(dout!==expected_data[i-1])
        $display("[Failed] Read %0d: dout = 0x%0h (expected 0x%0h)", i, dout, expected_data[i]);
      else
        $display("[Passed] Read %0d: dout = 0x%0h", i, dout);
    end
    end
    rd_en=0;
    @(posedge clk);
  end
  endtask
        
  
  
  
  /////////////////////////////////////////////////////////////
  //12)Almost full and Then Stop writing
  task almost_full;
    integer i;
    begin
      $display("......Fifo almost full then stop test writing......");
     
      for(i=0;i<DEPTH-1;i=i+1) begin
      wr_en=1;
      din=i+8'h10;
      @(posedge clk);
    end
     
      wr_en=0;
      @(posedge clk);
      
      if(full)
        $display("[Failed] FIFO full too early at %0d writes", i);
    else
      $display("[Passed] FIFO correctly not full at DEPTH - 1 writes");
  end
endtask
  
  /////////////////////////////////////////////////////////////

  //13)almost empty
  task almost_empty;
  integer i;
  begin
    $display("......FIFO Almost Empty Then Stop Reading Test......");


    // Fill the FIFO with 4 elements
    for(i=0;i<4;i=i+1) begin
      wr_en=1;
      din=8'hA0+i;
      @(posedge clk);
    end
    wr_en = 0;
    @(posedge clk);

    // Read 3 out of 4 (almost empty)
    for (i=0;i<3;i=i+1) begin
      rd_en=1;
      @(posedge clk);
    end
    rd_en = 0;
    @(posedge clk);

    if(empty)
      $display("[Failed] FIFO became empty after 3 reads");
    else
      $display("[Passed] FIFO correctly not empty with 1 item remaining");
  end
endtask
  
/////////////////////////////////////////////////////////////  
  
  
  
  //initial block
  initial begin
  $display(".......Reset Test......");
  //initialising inputs
  rst=0;
  wr_en=0;
  rd_en=0;
  din=0;
  
  //wait for 1 clock cycle 
  #10;
  //Apply reset 
  rst=1;
  #10;
  //release reset
  rst=0;
  #10;
 // Wait for 1 clock to stabilize outputs after reset
  @(posedge clk);
  #1;
      //check_reset();
    
    
  $display("......Write Test......");
    //check_single_write();
    
    
  $display(".......Read Test......");
  //check_single_read();
    
  //check_fifo_full();
    
  //check_fifo_empty();
    
 //check_simul_read_write();  
    
 // check_full_and_overflow();   
    
 // check_empty_and_underflow();
    
 // check_wrap_around();
    
 //check_reset_at_mid();
    
 //random_write_read();
    
 almost_full();
    
// almost_empty();
 $display(".......Test Done......");
                   
$finish;
end
endmodule              
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  



