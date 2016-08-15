
import Types::*;
import MemoryTypes::*;
import BRAM::*;

(* synthesize *)
module mkFPGAMemory(WideMem);
  BRAM_Configure cfg = defaultValue;
  cfg.memorySize = 0;
  cfg.latency = 2;
  cfg.loadFormat = tagged Hex "memory.vmh";

  BRAM1Port#(Bit#(22), WideLine) bram <- mkBRAM1Server(cfg);

  interface Server to_proc;
    interface Put request;
      method Action put(WideMemReq r);
        bram.portA.request.put( BRAMRequest{ write: (r.op == St)? True : False, responseOnWrite: False, address: truncate(r.addr>>2), datain: r.data } );
      endmethod
    endinterface

    interface Get response;
      method ActionValue#(WideMemResp) get();
        let d <- bram.portA.response.get;
        return d;
      endmethod
    endinterface
  endinterface

  interface Server to_host;
    interface Put request;
      method Action put(WideMemReq r);
        bram.portA.request.put( BRAMRequest{ write: (r.op == St)? True : False, responseOnWrite: False, address: truncate(r.addr>>2), datain: r.data } );
      endmethod
    endinterface

    interface Get response;
      method ActionValue#(WideMemResp) get();
        let d <- bram.portA.response.get;
        return d;
      endmethod
    endinterface
  endinterface
endmodule
