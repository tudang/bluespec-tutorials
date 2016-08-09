// This package contains a testbench for the DMA1 package.
package TestBench;

import FIFOF :: * ;
import StmtFSM :: * ;
import Connectable :: * ;
import Socket_IFC :: * ;

import DMA :: * ;
import Targets :: * ;

// Create a testbench module, which consists of a DMA and a simple
// MMU (slave).  The testbench configures the DMA and then waits for the
// DMA transfer to finish.

// Testbench interface is empty, thus having just a clock and reset
(* synthesize *)
module sysTestBench () ;

   // Instantiate the DMA  the DUT
   DMA2 dma <- mkDMA ;
   
   // In the test bench we want to synthesize 2 memories
   Socket_slave_ifc  mem1 <- mkDummyMemory( "memA" ) ;
   Socket_slave_ifc  mem2 <- mkDummyMemory( "memB" ) ;

   // Now connect the DMA to the memory
   Empty mmuConnection1 <- mkConnection( mem1, dma.mmu1 ) ;
   Empty mmuConnection2 <- mkConnection( mem2, dma.mmu2 ) ;

   // For ease, we create a master socket by
   // instantiating 2 fifos and connecting them to the DMA config
   // slave socket.  The testbench will be able to sent requests and
   // receive responses to theses fifos
   FIFOF#(Socket_Req)   cnf_req_f  <-  mkGSizedFIFOF(False, True, 2) ;
   FIFOF#(Socket_Resp)  cnf_resp_f <-  mkGSizedFIFOF(True, False, 2) ;
   let  configMaster = fifos_to_master_ifc( cnf_req_f, cnf_resp_f ) ;
   // and connect to the DMA
   Empty cfgConnection <- mkConnection(configMaster, dma.cfg ) ;
   
   
   // For convience, we define a function to build the request
   // structure for configuring the DMA
   function Action genConfig (ReqAddr maddr, 
                              ReqOp   cmd, 
                              ReqData mdata ) ;      
      let req = Socket_Req {reqAddr : maddr,
                            reqData : mdata,
                            reqOp   : cmd ,
                            reqInfo : 14 } ;
      return 
      action
         cnf_req_f.enq( req ) ;
      endaction;
   endfunction

   Stmt dmaConfig = 
   seq
      $display( "dmaConfig starting" ) ;
      // dmaConfig is a simple FSM to configure the DMA
      // Move 20 items from hex address 1000 to 2000 
      // Note that each request requires a deq from the fifo to take
      // the response from the DMA.
      genConfig( 'h00, WR, 'h0000_1000 ) ;
      genConfig( 'h04, WR,  20 ) ;
      cnf_resp_f.deq ;
      genConfig( 'h08, WR, 'h0000_5000 ) ;
      cnf_resp_f.deq ;
      // Do the DMA transfer from memB to memA
      genConfig( 'h10, WR, 'b01 ) ;
      cnf_resp_f.deq ;
      
      // Move 20 items from hex address 2000 to 7000 
      // Note that each request requires a deq from the fifo to take
      // the response from the DMA.
      genConfig( 'h100, WR, 'h0000_2000 ) ;
      cnf_resp_f.deq ;
      genConfig( 'h104, WR,  20 ) ;
      cnf_resp_f.deq ;
      genConfig( 'h108, WR, 'h0000_7000 ) ;
      cnf_resp_f.deq ;
      // Do the DMA transfer from memB to memA
      genConfig( 'h110, WR, 'b10 ) ;
      cnf_resp_f.deq ;
      
      action
         cnf_resp_f.deq ;
         $display( "damConfig done" ) ;
      endaction
   endseq ;
   

   Reg#(Bool) notZero0 <- mkReg( True ) ;
   Reg#(Bool) notZero1 <- mkReg( True ) ;
   
   Stmt waitTillDone0 =
   seq
      notZero0 <= True ;
      while ( notZero0 )
         seq
            // read the DMA status looking for a not enabled.
            genConfig( 'h0C, RD, 0 ) ;
            action
               cnf_resp_f.deq ;
               notZero0 <= 0 != cnf_resp_f.first.respData ;
            endaction
         endseq     
      $display( "DMA transfer finished" ) ;
      
   endseq ;
   Stmt waitTillDone1 =
   seq
      notZero1 <= True ;
      while ( notZero1 )
         seq
            // read the DMA status looking for a not enabled.
            genConfig( 'h10C, RD, 0 ) ; // channel 1
            action
               cnf_resp_f.deq ;
               notZero1 <= 0 != cnf_resp_f.first.respData ;
            endaction
         endseq     
      $display( "Channel 1 is complete." ) ;
   endseq ;

   // Another FSM to control overall sequeining
   Stmt testCtrl =
   seq
      dmaConfig ;
      //
      $display( "Starting the DMA controller channel 0" ) ;
      genConfig( 'h0C, WR, 'h0000_0001 ) ;               cnf_resp_f.deq ;
      waitTillDone0 ;

      $display( "Finished  run of channel 0, starting channel 1" ) ;
      genConfig( 'h10C, WR, 'h0000_0001 ) ;               cnf_resp_f.deq ;
      waitTillDone1 ;
      $display( "Finished  run of channel 1, starting both channels" ) ;
      genConfig( 'h00C, WR, 'h0000_0001 ) ;               cnf_resp_f.deq ;
      genConfig( 'h10C, WR, 'h0000_0001 ) ;               cnf_resp_f.deq ;
      $display( "Both channels started" ) ;
      par
         waitTillDone0 ;
         waitTillDone1 ;
      endpar
      $display( "Both channels finished" ) ;
      
   endseq ;
   
   // Create an FSM from the test sequence.
   mkAutoFSM( testCtrl ) ;
   
   // 
   Reg#(int) c <- mkReg(0) ;
   rule ticker ( True ) ;
      c <= c + 1;
      $display("cycle: %0d", c ) ;
      if ( c > 5000 ) 
         begin
            $display ("Simulation finished because of timeout" ) ; 
            $finish(0);
         end
   endrule
   
endmodule


endpackage 
