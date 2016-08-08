// This package contains a testbench for the DMA1 package.
package TestBench;

import FIFOF :: * ;
import StmtFSM :: * ;
import Connectable :: * ;
import Socket_IFC :: * ;

//import DMAold :: * ;
import DMA :: * ;
import Targets :: * ;

// Create a testbench module, which consists of a DMA and a simple
// MMU (slave).  The testbench configures the DMA and then waits for the
// DMA transfer to finish.

// Testbench interface is empty, thus having just a clock and reset
(* synthesize *)
module sysTestBench () ;

   // Instantiate the DMA  the DUT
   DMA1 dma <- mkDMA ;
   
   // In the test bench we want to synthesize one dummy memory
   Socket_slave_ifc  mem <- mkDummyMemory( "mem" ) ;

   // Now connect the DMA to the memory
   Empty mmuConnection <- mkConnection( mem, dma.mmu ) ;

   // For ease, we create a master socket by
   // instantiating 2 fifos and connecting them to the DMA config
   // slave socket.  The testbench will be able to sent requests and
   // receive responses to theses fifos
   FIFOF#(Socket_Req)   cnf_req_f  <- mkGSizedFIFOF(False, True, 2) ;
   FIFOF#(Socket_Resp)  cnf_resp_f <- mkGSizedFIFOF(True, False, 2) ;
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
      // the reponse from the DMA.
      genConfig( 'h00, WR, 'h0000_1000 ) ;

      genConfig( 'h04, WR,  20 ) ;
      cnf_resp_f.deq ;

      genConfig( 'h08, WR, 'h0000_5000 ) ;
      cnf_resp_f.deq ;

      action
         cnf_resp_f.deq ;
         $display( "dmaConfig done" ) ;
      endaction
   endseq ;
   

   Reg#(Bool) notZero <- mkReg( True ) ;
   // Another FSM to control overall sequeining
   Stmt testCtrl =
   seq
      dmaConfig ;
      //
      action         
         genConfig( 'h0C, WR, 'h0000_0001 ) ;
         $display( "Starting the DMA controller" ) ;
      endaction 
      cnf_resp_f.deq ;

      notZero <= True ;
      while ( notZero )
         seq
            // read the DMA status looking for a not enabled.
            genConfig( 'h0C, RD, 0 ) ;
            action
               cnf_resp_f.deq ;
               notZero <= 0 != cnf_resp_f.first.respData ;
            endaction
         endseq     
      $display( "DMA transfer finished" ) ;
      
   endseq ;
   
   // Create an FSM from the test sequence.
   mkAutoFSM( testCtrl ) ;
   
   // 
   Reg#(int) c <- mkReg(0) ;
   rule ticker ( True ) ;
      c <= c + 1;
      $display("cycle: %0d", c ) ;
      if ( c > 1000 ) 
         begin
            $display ("Simulation finished because of timeout" ) ; 
            $finish(0);
         end
   endrule
   
endmodule


endpackage 
