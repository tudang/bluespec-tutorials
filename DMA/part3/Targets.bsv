
package Targets ;

import Socket_IFC :: * ;
import FIFOF :: * ;


// For the test bench, we will need a "memory" module with a Socket
// slave interface.  Since this is just needed for a testbench timing
// characteristics are not critical.
// a modName is include for debug

module mkDummyMemory #( String modName )( Socket_slave_ifc ) ;

   // The Socket slave will need 2 fifos -- one for request and the other
   // for responses.
   FIFOF#(Socket_Req) requestF <- mkGSizedFIFOF(True, False, 2) ;
   FIFOF#(Socket_Resp) responseF <- mkGSizedFIFOF(False, True, 2) ;

   // A few rules are need to "respond" to requests
   rule readReq ( requestF.first.reqOp == RD );
      requestF.deq ;
      let req = requestF.first ;
      $write("Target %s: ", modName );
      display_Socket_Req( req ) ;
      
      // Change the address to Data.
      Bit#(32) trans = zeroExtend( req.reqAddr ) ;

      // Now generate the response and enqueue
      let resp = Socket_Resp {respOp   : OK,
                              respAddr : 0,
                              respInfo : req.reqInfo,
                              respData : {trans, trans } } ;
      responseF.enq( resp ) ;
   endrule

   rule writeReq ( requestF.first.reqOp == WR );
      requestF.deq ;
      let req = requestF.first ;
      $write("Target %s: ", modName );
      display_Socket_Req( req ) ;

      // Now generate the response and enqueue
      let resp = Socket_Resp {respOp   : OK,
                              respAddr : 0,
                              respInfo : req.reqInfo,
                              respData : req.reqData } ;
      responseF.enq( resp ) ;
   endrule

   
   (* descending_urgency = "readReq, writeReq,  unsupportedReq" *)
   rule unsupportedReq ( True );
      requestF.deq ;
      let req = requestF.first ;
      $write("Unsupported request at Target %s: ", modName );
      display_Socket_Req( req ) ;

      // Now generate the response and enqueue
      let resp = Socket_Resp {respOp   : NOP,
                              respAddr : 0,
                              respInfo : req.reqInfo,
                              respData : req.reqData } ;
      responseF.enq( resp ) ;
   endrule
   
   return fifos_to_slave_ifc( requestF, responseF ) ;   
   
endmodule

endpackage
