package Socket_IFC;

// ================================================================
// Copyright (c) Bluespec, Inc., 2006 All Rights Reserved

// ----------------
// Imports from BSV libs

import FIFOF::*;
import Connectable:: *;

// ----------------
// Requests across a socket

typedef enum { NOP, WR, RD } ReqOp
        deriving (Bits, Eq);

function Action display_ReqOp (ReqOp op);
   case (op)
      NOP : $write ("NOP");
      WR  : $write ("WR");
      RD  : $write ("RD");
   endcase
endfunction

typedef Bit#(10)  ReqInfo;
typedef Bit#(24)  ReqAddr;
typedef Bit#(64)  ReqData;

typedef struct {
  ReqOp                  reqOp;
  ReqInfo                reqInfo;
  ReqAddr                reqAddr;
  ReqData                reqData;
} Socket_Req
  deriving (Bits);

function Action display_Socket_Req (Socket_Req req);
   action
     $write ("Socket_Req{");
     display_ReqOp (req.reqOp);
     if (req.reqOp != NOP)
        $write (", %h, %h, %h}", req.reqInfo, req.reqAddr, req.reqData);
     $display ("}");
   endaction
endfunction

// ================================================================
// Socket Responses

typedef enum { NOP, OK } RespOp
        deriving (Bits, Eq);

function Action display_RespOp (RespOp op);
   case (op)
      NOP  : $write ("NOP");
      OK   : $write ("OK");
   endcase
endfunction

typedef Bit#(10)   RespInfo;
typedef Bit#(1)    RespAddr;
typedef Bit#(64)   RespData;

typedef struct {
  RespOp                 respOp;
  RespInfo               respInfo;
  RespAddr               respAddr;
  RespData               respData;
} Socket_Resp
  deriving (Eq, Bits);

function Action display_Socket_Resp (Socket_Resp resp);
   action
     $write ("Socket_Resp{");
     display_RespOp (resp.respOp);
     if (resp.respOp != NOP)
        $write (", %h, %h, %h", resp.respInfo, resp.respAddr, resp.respData);
     $display ("}");
   endaction
endfunction

// ================================================================
// Generic Socket Interfaces
// These interfaces will be "always ready, always enabled"
// so that there are no extra signal wires beyong what is implied by
// the argument and result types of the methods

// ----------------
// A master interface
//   exists on an Initiator    (facing a slave interface on an Interconnect)
//      and on an Interconnect (facing a slave interface on a Target)

(* always_ready *)
interface Socket_master_req_ifc;
   method ReqOp    getReqOp    ();
   method ReqInfo  getReqInfo  ();
   method ReqAddr  getReqAddr  ();
   method ReqData  getReqData  ();

   method Action   reqAccept   ();
endinterface: Socket_master_req_ifc

(* always_ready, always_enabled *)
interface Socket_master_resp_ifc;
   method Action  putResp    (RespOp    respOp,
                              RespInfo  respInfo,
                              RespAddr  respAddr,
                              RespData  respData);
   method Bool    respAccept ();
endinterface: Socket_master_resp_ifc

interface Socket_master_ifc;
   interface Socket_master_req_ifc   master_req;
   interface Socket_master_resp_ifc  master_resp;
endinterface: Socket_master_ifc

// The following function produces an Socket master interface from the
// interfaces of two fifos containing requests and responses

function Socket_master_ifc
         fifos_to_master_ifc (FIFOF#(Socket_Req)  reqs,
                              FIFOF#(Socket_Resp) resps);
   return
     (interface Socket_master_ifc
         interface Socket_master_req_ifc  master_req;
            method ReqOp  getReqOp ();
               return reqs.notEmpty ? reqs.first.reqOp : NOP ;
            endmethod
            method ReqInfo  getReqInfo ();
               return reqs.first.reqInfo ;
            endmethod
            method ReqAddr  getReqAddr ();
               return reqs.first.reqAddr ;
            endmethod
            method ReqData  getReqData ();
               return reqs.first.reqData ;
            endmethod

            method Action  reqAccept  ();
               if (reqs.notEmpty)
                  reqs.deq ();
            endmethod
         endinterface

         interface Socket_master_resp_ifc  master_resp;
            method Action  putResp (RespOp    respOp,
                                    RespInfo  respInfo,
                                    RespAddr  respAddr,
                                    RespData  respData);
               if ((respOp != NOP) && resps.notFull ()) begin
                  let resp = Socket_Resp { respOp : respOp,
                                           respInfo : respInfo,
                                           respAddr :respAddr,
                                           respData : respData };                       
                  resps.enq (resp);
               end
            endmethod

            method Bool  respAccept ();
               return resps.notFull();
            endmethod
         endinterface
      endinterface);
endfunction: fifos_to_master_ifc

// ----------------
// A slave interface
//   exists on an Interconnect (facing a master interface on an Initiator)
//      and on a  Target       (facing a master interface on an Interconnect)

(* always_ready, always_enabled *)
interface Socket_slave_req_ifc;
   method Action  putReq (ReqOp    reqOp,
                          ReqInfo  reqInfo,
                          ReqAddr  reqAddr,
                          ReqData  reqData);
   method Bool    reqAccept  ();
endinterface: Socket_slave_req_ifc

(* always_ready *)
interface Socket_slave_resp_ifc;
   method RespOp    getRespOp    ();
   method RespInfo  getRespInfo  ();
   method RespAddr  getRespAddr  ();
   method RespData  getRespData  ();
   method Action    respAccept   ();
endinterface: Socket_slave_resp_ifc

interface Socket_slave_ifc;
   interface Socket_slave_req_ifc   slave_req;
   interface Socket_slave_resp_ifc  slave_resp;
endinterface: Socket_slave_ifc

// The following function produces an Socket slave interface from the
// interfaces of two fifos containing requests and responses

function Socket_slave_ifc
         fifos_to_slave_ifc (FIFOF#(Socket_Req)  reqs,
                             FIFOF#(Socket_Resp) resps);
   return
     (interface Socket_slave_ifc
         interface Socket_slave_req_ifc  slave_req;
            method Action  putReq (ReqOp      reqOp,
                                   ReqInfo    reqInfo,
                                   ReqAddr    reqAddr,
                                   ReqData    reqData);
               if ((reqOp != NOP) && (reqs.notFull)) begin
                  let req = Socket_Req { reqOp : reqOp,
                                         reqInfo: reqInfo,
                                         reqAddr: reqAddr,
                                         reqData: reqData };
                  reqs.enq (req);
               end
            endmethod

            method Bool reqAccept ();
               return reqs.notFull;
            endmethod
         endinterface

         interface Socket_slave_resp_ifc  slave_resp;
            method RespOp  getRespOp ();
               return (resps.notEmpty ? resps.first.respOp : NOP);
            endmethod
            method RespInfo  getRespInfo ();
               return (resps.first.respInfo ) ;
            endmethod
            method RespAddr  getRespAddr ();
               return (resps.first.respAddr ) ;
            endmethod
            method RespData  getRespData ();
               return (resps.first.respData ) ;
            endmethod

            method Action  respAccept ();
               if (resps.notEmpty)
                  resps.deq;
            endmethod
         endinterface
      endinterface);
endfunction: fifos_to_slave_ifc

// ================================================================
// Connections for the specialized socket interfaces

instance Connectable #(Socket_master_ifc, Socket_slave_ifc);
   module mkConnection #(Socket_master_ifc  master,
                         Socket_slave_ifc   slave)
                       (Empty);

      (* no_implicit_conditions, fire_when_enabled *)
      rule relay_req (True) ;
         slave.slave_req.putReq (master.master_req.getReqOp,
                                 master.master_req.getReqInfo,            
                                 master.master_req.getReqAddr,
                                 master.master_req.getReqData );
      endrule

      (* no_implicit_conditions, fire_when_enabled *)
      rule relay_req_accpt (slave.slave_req.reqAccept) ;
         master.master_req.reqAccept ;
      endrule
      
      (* no_implicit_conditions, fire_when_enabled *)
      rule relay_resp (True) ;
         master.master_resp.putResp (slave.slave_resp.getRespOp,
                                     slave.slave_resp.getRespInfo,
                                     slave.slave_resp.getRespAddr,
                                     slave.slave_resp.getRespData
                                     );
      endrule

      (* no_implicit_conditions, fire_when_enabled *)
      rule relay_resp_accpt (master.master_resp.respAccept) ;
         slave.slave_resp.respAccept ;
      endrule
      
   endmodule
endinstance

instance Connectable #(Socket_slave_ifc, Socket_master_ifc);
   module mkConnection #(Socket_slave_ifc   slave,
                         Socket_master_ifc  master)
                       (Empty);
      mkConnection (master, slave);
   endmodule
endinstance

// ================================================================
// At time is best to consider Registers as completly homogeneous,
// that is everything is n (32) bits, and one can read and write to
// all bit, even if the write action is not allowed.
// These function convert Reg interfaces of smaller sizes to uniformed
// sized ones.

function Reg#(Bit#(n)) regAToRegBitN( Reg#(a_type) rin )
   provisos ( Bits#( a_type, asize),
             Add#(asize,xxx,n) ) ;

   return
   interface Reg
      method Bit#(n) _read ();
         a_type tmp =  rin._read()  ;
         return zeroExtend (pack( tmp )) ;
      endmethod
      method Action _write( Bit#(n) din );
         rin._write( unpack( truncate(din) )) ;
      endmethod
   endinterface ;

endfunction

function Reg#(Bit#(n)) regAToRegBitN_ReadOnly( Reg#(a_type) rin )
   provisos ( Bits#( a_type, asize),
             Add#(asize,xxx,n) ) ;

   return
   interface Reg
      method Bit#(n) _read ();
         a_type tmp =  rin._read()  ;
         return zeroExtend (pack( tmp )) ;
      endmethod
      method Action _write( Bit#(n) din );
         // no action here, since this is read only!
      endmethod
   endinterface ;

endfunction


endpackage: Socket_IFC
