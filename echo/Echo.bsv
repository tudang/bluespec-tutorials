import FIFO::*;
import Vector::*;

interface EchoIndication;
	method Action heard(Bit#(32) v);
endinterface

interface EchoRequest;
	method Action say(Bit#(32) v);
endinterface

interface Echo;
	interface EchoRequest request;
endinterface

module mkEcho#(EchoIndication indication)(Echo);
	FIFO#(Bit#(32)) delay <- mkSizedFIFO(8);

	rule heard;
		delay.deq;
		indication.heard(delay.first);
	endrule

	interface EchoRequest request;
		method Action say(Bit#(32) v);
			delay.enq(v);
		endmethod
	endinterface
endmodule
