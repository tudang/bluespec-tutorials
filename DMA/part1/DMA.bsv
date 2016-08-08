package DMA ;

import Socket_IFC :: * ;
import FIFO :: * ;
import FIFOF :: * ;


// A simple DMA interface consists of 1 master port (mmu) to initiate 
// the transfer and 1 slave port (cfg) which to configure the status
// registers.
interface DMA1 ;
   interface Socket_slave_ifc    cfg ;
   interface Socket_master_ifc   mmu ;
endinterface  

typedef UInt#(16)  DMACounts ;
// In this version, we build a simple dma transfer engine using an FSM
// implemented using Bluespec rules.
// The basic DMA transfer is to start a read, get the result and write
// it out to the destination address.
// Several configuration registers are included, and connected to the
// config socket/fifo.

//TODO:  Define a set of states for the DMA engine, DMA_State
typedef enum { Idle, ReadFinish, Write, WriteFinish } DMA_State deriving ( Bits, Eq ) ;


(* synthesize *)
module mkDMA( DMA1 );    

   // For each socket, we will need 2 fifos, one for request, and 1
   // for response.  These fifos provide the interface for the
   // interface sockets

   ////////////////////////////////////////////////////////////////   
   // The fifos for the config port
   FIFOF#(Socket_Req)   cnfReqF  <- mkGSizedFIFOF(True, False, 2) ;
   FIFOF#(Socket_Resp)  cnfRespF <- mkGSizedFIFOF(False, True, 2)  ;

   // TODO: Instantiate the fifos for the mmu, mmuReqF and mmuRespF
   FIFOF#(Socket_Resp)   mmuRespF <- mkGSizedFIFOF(True, False, 2) ;
   FIFOF#(Socket_Req)    mmuReqF  <- mkGSizedFIFOF(False, True, 2)  ;


   ////////////////////////////////////////////////////////////////   
   // We will need some registers to control the DMA transfer
   // A Bit to signal if the transfer is enabled
   Reg#(Bool)       dmaEnabledR <- mkReg( False ) ;
   
   //  The read address and other stuff needed to generate a read
   Reg#(ReqAddr)        readAddrR <- mkReg(0) ;
   Reg#(DMACounts)      readCntrR <- mkReg(0) ; // number of data to transfer
   Reg#(DMACounts)   currentReadR <- mkReg(0) ;// number of reads processed
   Reg#(DMACounts)  currentWriteR <- mkReg(0) ;// number of writes processed

   //  The destination address
   Reg#(ReqAddr)  destAddrR     <- mkReg(0) ;
   // And a register to hold the response
   Reg#(ReqData)   responseDataR <- mkReg(0) ;
   // TODO: Instantiate the state register dmaStateR
   Reg#(DMA_State) dmaStateR <- mkReg(Idle);

   

   /// TO DO  DMA rule startRead//////////////////////////////////////////////
   // To start a read, when the dma is enabled and there are data to
   // move, and we are in the right state 
   (* descending_urgency =  "startWrite, startRead" *)
   rule startRead ( dmaEnabledR && (readCntrR > currentReadR) && (dmaStateR == Idle)  ) ;
      
      // Create a read request, and enqueue it
      // Since there can be multiple pending requests, either read or
      // writes, we use the reqInfo field to mark these.  reqInfo
      // indicates the channel and whether it is a RD or WR.  E.g.:
      //   0 means RD for channel 0
      //   1 means WR for channel 0
      //   2 means RD for channel 1
      //   etc...
      Socket_Req req = Socket_Req { reqAddr : readAddrR,
      					reqData : 0,
					reqOp : RD,
					reqInfo : 1 };
      mmuReqF.enq(req);

      // Some house keeping -- increment the read address,
      // increment the counter.
      readAddrR <= readAddrR + 1;
      currentReadR <= currentReadR + 1;
      $display("DMA startRead currentReadR:[%d]", currentReadR);
      dmaStateR <= ReadFinish;
   endrule

   // TO DO: rule finishRead
   // We want to do the read and write in 2 steps to decouple the
   // response and request sides of the master port
   rule finishRead ( dmaStateR == ReadFinish   ) ;
   // grab the data from the mmu reponse fifo
   let resp = mmuRespF.first();
   mmuRespF.deq();

   // Save the data so it can be written in the next state
   responseDataR <= resp.respData;
   $display("DMA: finishRead");
   dmaStateR <= Write;

      
   endrule

   // This rule start the write process
   // Note that this rule conflicts with rule start Read, so we make
   // this reule more urgent                       
   rule startWrite ( dmaStateR == Write ) ;
      let wreq = Socket_Req {reqAddr : destAddrR,
                             reqData : responseDataR,
                             reqOp   : WR,
                             reqInfo : 2};

      // enqueue the request.
      mmuReqF.enq( wreq ) ;
   
      // Some other house keeping
      destAddrR <= destAddrR + 1;
      $display ("DMA startWrte");                       
      dmaStateR <= WriteFinish ;
   endrule

   // This rule waits for the write to finish
   rule finishWrite (dmaStateR == WriteFinish ) ;
         
      mmuRespF.deq() ;          // take the response data and finish
      $display ("DMA: finishWrite currentWriteR [%d]", currentWriteR);

      dmaStateR <= Idle ;     // back to idle
      if ( currentWriteR + 1 < readCntrR )
         begin
            currentWriteR <= currentWriteR + 1 ;
         end
      else
         begin // Transfer is done
            dmaEnabledR   <= False ; 
            currentWriteR <= 0 ;
            currentReadR  <= 0 ;
         end
    endrule

   //  Rules and other code to interface config port /////////////

   // Add a zero-size register as a default for invalid addresses
   Reg#(Bit#(0)) nullReg <- mkReg( ? ) ;

   // For ease of development we want all registers to look like 32
   // bit resister-- the data size of the config socket.
   // Create function to map from address to specific registers
   function Reg#(ReqData) selectReg( ReqAddr addr ) ;
      Bit#(12) taddr = truncate( addr ) ;
      return
      case ( taddr )
         12'h00 :  return regAToRegBitN( readAddrR ) ;
         12'h04 :  return regAToRegBitN( readCntrR ) ;
         12'h08 :  return regAToRegBitN( destAddrR ) ;
         12'h0C :  return regAToRegBitN( dmaEnabledR ) ;         
         12'h10 :  return regAToRegBitN( nullReg ) ;
      endcase ;
   endfunction

   // A rule for writing to a registers
   rule writeConfig ( cnfReqF.first.reqOp == WR ) ;
      let req =  cnfReqF.first ;
      cnfReqF.deq ;

      // Select and write the register 
      let thisReg = selectReg( req.reqAddr ) ;
      thisReg <= req.reqData ;

      // Now generate the response and enqueue
      let resp = Socket_Resp {respOp   : OK,
                              respAddr : 0,
                              respInfo : req.reqInfo,
                              respData : req.reqData } ;
      cnfRespF.enq( resp ) ;
   endrule
   
   // A rule for reading a configuration register 
   rule readConfig ( cnfReqF.first.reqOp == RD ) ;
      let req =  cnfReqF.first ;
      cnfReqF.deq ;

      // Select the register 
      let thisReg = selectReg( req.reqAddr ) ;

      // Now generate the response and enqueue
      let resp = Socket_Resp {respOp   : OK,
                              respAddr : 0,
                              respInfo : req.reqInfo,
                              respData : thisReg } ;
      cnfRespF.enq( resp ) ;
   endrule

   (* descending_urgency = 
    "writeConfig, readConfig, unknownConfig"  *)
   rule unknownConfig ( True ) ;
      let req =  cnfReqF.first ;
      cnfReqF.deq ;

      // Select the register 
      let thisReg = selectReg( req.reqAddr ) ;

      // Now generate the response and enqueue
      let resp = Socket_Resp {respOp   : NOP,
                              respAddr : 0,
                              respInfo : req.reqInfo,
                              respData : thisReg } ;
      cnfRespF.enq( resp ) ;
   endrule
   
   ////////////////////////////////////////////////////////////////  
   // Create the interfaces by converting the fifo interfaces to the
   interface cfg = fifos_to_slave_ifc(  cnfReqF, cnfRespF ) ;
   interface mmu = fifos_to_master_ifc( mmuReqF, mmuRespF ) ;
endmodule


endpackage


         
