package DMA ;

import Socket_IFC :: * ;
import FIFO :: * ;
import FIFOF :: * ;
import Vector::*;



// In this version,  we add an additional channel to the DMA,  that is
// the DMA can process 2 transfers simultaneously.
// The significant change is to create Vectors of the the objects
// which must be unique for each channel.

// In this version, we add an additional MMU port, which could
// represent, a MMU with separate read and write ports, different
// memories, or a separate bus for peripherals.


interface DMA2 ;
   interface Socket_slave_ifc    cfg ;
   interface Socket_master_ifc   mmu1 ;
   interface Socket_master_ifc   mmu2 ;
endinterface  

typedef UInt#(16)  DMACounts ;
// The number of channels is a parameter.
typedef 2 NumChannels;

// For the module, we add additional configuration registers to control
// which port the transfer reads from and writes to.  
// The majority of the design remains the same, additional fifos, and
// interface must be added, as well as adding new rules to control
// which port is read or written.

// Several configuration registers are included, and connected to the
// config socket/fifo.


(* synthesize *)
module mkDMA( DMA2 );    

   // For each socket, we will need 2 fifos, one for request, and 1
   // for response.  These fifos provide the interface for the
   // interface sockets

   ////////////////////////////////////////////////////////////////   
   // The fifos for the config port -- these are 1 element pipeline fifos.
   FIFOF#(Socket_Req)   cnfReqF  <- mkGSizedFIFOF(True, False, 2) ;
   FIFOF#(Socket_Resp)  cnfRespF <- mkGSizedFIFOF(False, True, 2)  ;

   // The fifos for the MMU1
   FIFOF#(Socket_Req)  mmu1ReqF  <- mkGSizedFIFOF(False, True, 2);
   FIFOF#(Socket_Resp) mmu1RespF <- mkGSizedFIFOF(True, False, 2);

   // The fifos for the MMU2
   FIFOF#(Socket_Req)  mmu2ReqF  <- mkGSizedFIFOF(False, True, 2);
   FIFOF#(Socket_Resp) mmu2RespF <- mkGSizedFIFOF(True, False, 2);

   
   
   ////////////////////////////////////////////////////////////////   
   // We will need some registers to control the DMA transfer
   // A Bit to signal if the transfer is enabled   
   Vector#(NumChannels, Reg#(Bool))  dmaEnabledRs   <- replicateM(mkReg(False));

   //  The read address and other stuff needed to generate a read
   // Add readAddrRs, readCntrRs, currentReadRs, currentWriteRs
   Vector#(NumChannels, Reg#(ReqAddr))       readAddrRs <- replicateM(mkReg(0));
   Vector#(NumChannels, Reg#(DMACounts))     readCntrRs <- replicateM(mkReg(0));
   Vector#(NumChannels, Reg#(DMACounts))  currentReadRs <- replicateM(mkReg(0));
   Vector#(NumChannels, Reg#(DMACounts)) currentWriteRs <- replicateM(mkReg(0));
   
   
   // To distinguish the ports for reads and writes, we need 2 bits
   // TODO:  Add portSrcDestRs
   Vector#(NumChannels, Reg#(Bit#(2))) portSrcDestRs <- replicateM(mkReg(0));
   
   
   // The destination address
   // Add destAddrRs
   Vector#(NumChannels, Reg#(ReqAddr)) destAddrRs <- replicateM(mkReg(0));
   

   // Use a FIFO to pass the read response to the write "side",
   //  thus allowing pending transations and concurrency.
   // FIFOs can be replicated as well.
   // Add responseDataFs (mkSizedFIFO(2))
   Vector#(NumChannels, FIFO#(ReqData)) responseDataFs <- replicateM(mkSizedFIFO(2));
   
   
   
   // We also want to pass the destination address for each read over
   // to the write "side"
   // The depth of this fifo limits the number of outstanding reads
   // which may be pending before the write.  The maximum outstanding
   // reads depends on the overall latency of the read requests.
   // Add destAddrFs (mksSizedFIFO(4))
   Vector#(NumChannels, FIFO#(ReqAddr)) destAddrFs <- replicateM(mkSizedFIFO(4));
   
   
   
   
   ///  DMA rules //////////////////////////////////////////////////
   // We define a function inside the module so it can access some
   // of the registers without passing too many arguments.  
   // The function takes as arguments the conditions and fifos
   // (interfaces)
   // And returns a set a rules.
   // The rule are identical to the set used in the one mmu port case.
   function Rules generatePortDMARules (FIFOF#(Socket_Req)  requestF,
                                        FIFOF#(Socket_Resp) responseF,
                                        Integer chanNum
                                        );
      return
      rules

      // To start a read, when the dma is enabled and there are data to
      // move, and we are in the right state 

      (* descending_urgency =  "startWrite, startRead" *)
      rule startRead (dmaEnabledRs[chanNum] && 
                      readCntrRs[chanNum] > currentReadRs[chanNum] );
      
      // Create a read request, and enqueue it
      // Since there can be multiple pending requests, either read or
      // writes, we use the reqInfo field to mark these.  reqInfo
      // indicates the channel and whether it is a RD or WR.  E.g.:
      //   0 means RD for channel 0
      //   1 means WR for channel 0
      //   2 means RD for channel 1
      //   etc...
      let req = Socket_Req {reqAddr : readAddrRs[chanNum],
                            reqData : 0,
                            reqOp   : RD,
                            reqInfo : fromInteger(0 + 2*chanNum)};

      requestF.enq( req );
      destAddrFs[chanNum].enq(destAddrRs[chanNum]) ;

      // Some house keeping -- increment the read address,
      // increment the counter.
      readAddrRs[chanNum]    <= readAddrRs[chanNum] + 1 ;
      currentReadRs[chanNum] <= currentReadRs[chanNum] + 1 ;
      destAddrRs[chanNum]    <= destAddrRs[chanNum] + 1;
      $display("DMA startRead currentReadRs[%d]:[%d]", chanNum, currentReadRs[chanNum]);
      endrule
         
      // We want to do the read and write in 2 steps to decouple the
      // response and request sides of the master port
      // We finish a read when we see the correct respInfo on the mmu
 
      rule finishRead (responseF.first.respInfo == fromInteger(0 + 2*chanNum));
      // grab the data from the mmu reponse fifo
         Socket_Resp resp = responseF.first ;     
         responseF.deq() ;

      // Need to consider what to do if the response is an error or
      // fail but we will keep it simple for now

      // Save the data so it can be written in the next state
         responseDataFs[chanNum].enq (resp.respData) ;
         $display ("DMA: finishRead");
      endrule

      // This rule start the write process
      // Note that this rule conflicts with rule start Read, so we make
      // this rule more urgent                       
      rule startWrite ;     

      // Generate a Write 
         let wreq = Socket_Req {reqAddr : destAddrFs[chanNum].first(),
                                reqData : responseDataFs[chanNum].first(),
                                reqOp   : WR,
                                reqInfo : fromInteger(1 + 2*chanNum)};

         // enqueue the request.
         requestF.enq( wreq ) ;
   
         // Some other house keeping
         destAddrFs[chanNum].deq;
         responseDataFs[chanNum].deq();
	 destAddrRs[chanNum] <= destAddrRs[chanNum] + 1;
         $display ("DMA startWrte");                       
      endrule

      // This rule waits for the write to finish
      rule finishWrite (responseF.first().respInfo == fromInteger(1 + 2*chanNum));
         
         responseF.deq() ;          // take the response data and finish
         currentWriteRs[chanNum] <= currentWriteRs[chanNum] + 1 ;
         $display ("DMA: finishWrite currentWriteRs[%d]: [%d]", chanNum, currentWriteRs[chanNum]);

      endrule

      rule markTransferDone (dmaEnabledRs[chanNum] &&
                              currentWriteRs[chanNum] == readCntrRs[chanNum]    &&
                              currentReadRs[chanNum]  == readCntrRs[chanNum] );
        dmaEnabledRs[chanNum] <= False;
        currentWriteRs[chanNum] <= 0;
        currentReadRs[chanNum] <= 0;
        $display ("DMA transfer done"); 
      endrule
      endrules ;
   endfunction
   
//   Generate the rules, place them in priority order
   
   Rules ruleset = emptyRules;
      ruleset = rJoinDescendingUrgency (ruleset,
					generatePortDMARules( mmu1ReqF, mmu1RespF, 0));
      ruleset = rJoinDescendingUrgency (ruleset,
					generatePortDMARules( mmu2ReqF, mmu2RespF, 1));

   // Add the rules to this module
   addRules( ruleset ) ;  
   
   
   
   ///  Rules and other code to interface config port /////////////

   // Add a zero-size register as a default for invalid addresses
   Reg#(Bit#(0)) nullReg <- mkReg( ? ) ;

   // For ease of development we want all registers to look like 32
   // bit resister-- the data size of the config socket.
   // Create function to map from address to specific registers
   // For the multi channel DMA, split the 12 bit address into 2
   // fields, 4 bits to select the channel, 8 for the register.
   
   function Reg#(ReqData) selectReg( ReqAddr addr ) ;
      Bit#(8) taddr = truncate( addr ) ;
      Bit#(4) channelSel = truncate ( addr >> 8 ) ;
      return
      case ( taddr )
         8'h00 :  return regAToRegBitN( readAddrRs[channelSel] ) ;
         8'h04 :  return regAToRegBitN( readCntrRs[channelSel] ) ;
         8'h08 :  return regAToRegBitN( destAddrRs[channelSel] ) ;
         8'h0C :  return regAToRegBitN( dmaEnabledRs[channelSel] ) ;         
         8'h10 :  return regAToRegBitN( portSrcDestRs[channelSel] ) ;
         default:  return regAToRegBitN( nullReg ) ;
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
   interface mmu1 = fifos_to_master_ifc( mmu1ReqF, mmu1RespF ) ;
   interface mmu2 = fifos_to_master_ifc( mmu2ReqF, mmu2RespF ) ;      
endmodule


endpackage


         
