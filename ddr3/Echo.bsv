import FIFO::*;
import Types::*;
import MemoryTypes::*;
import BRAM::*;
import FPGAMemory::*;
import Vector::*;

interface EchoIndication;
	method Action heard(Bit#(64) v);
endinterface

interface EchoRequest;
	method Action say(Bit#(64) v);
	method Action get();
endinterface

interface Echo;
       	interface EchoRequest request;
endinterface

module mkEcho#(EchoIndication indication)(Echo);
	WideMem mem <- mkFPGAMemory();
	WideByteEn en = replicate(True);
	Addr addr = 64'h02;

	rule heard;
		let r <- mem.to_proc.response.get();
		let v = unpack(pack(r));
		indication.heard(v);
	endrule

	interface EchoRequest request;
		method Action say(Bit#(64) v);
			WideLine d = v;
			let req = WideMemReq { op: St, byteEn: en, addr: addr, data: d};
			mem.to_proc.request.put(req);
			indication.heard(64'h00);
		endmethod

		method Action get();
			let req = WideMemReq { op: Ld, byteEn: en, addr: addr, data: 0};
			mem.to_proc.request.put(req);
		endmethod
	endinterface
endmodule

