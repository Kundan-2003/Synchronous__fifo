module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16,
    parameter ADDR_WIDTH  = $clog2(DEPTH) //addr_width=4
)(
    input wire clk,
    input wire rst,
    input wire wr_en,
    input wire rd_en,
    input wire [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout,
    output wire full,
    output wire empty
);
  
  reg [DATA_WIDTH-1:0]mem[0:DEPTH-1];
  
  //we need two pointer->with two n+1 bit 
  reg [ADDR_WIDTH :0]wr_ptr; 
  reg [ADDR_WIDTH :0]rd_ptr;
  
  assign empty=(wr_ptr==rd_ptr);
  assign full=(wr_ptr[ADDR_WIDTH ]!=rd_ptr[ADDR_WIDTH ]) && (wr_ptr[ADDR_WIDTH -1:0]==rd_ptr[ADDR_WIDTH -1:0]); 
  
  //for write
  always @(posedge clk) begin
    if(rst) begin
      wr_ptr<=0;
    end else if(wr_en && !full) begin
      mem[wr_ptr[ADDR_WIDTH -1:0]]<=din; //msb is used for comprassion, except msb all are used for store data
      wr_ptr<=wr_ptr+1;
  end
  end
  
  //for read
 always @(posedge clk) begin
   if(rst) begin
     rd_ptr<=0;
     dout<=0;
   end else if(rd_en &&!empty) begin
     dout<=mem[rd_ptr[ADDR_WIDTH -1:0]];
     rd_ptr<=rd_ptr+1;
   end else if(empty) begin
     dout<=0;
   end
 end
 endmodule
  
  
  
  
  
  
  
  
