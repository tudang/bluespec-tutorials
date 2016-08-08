import FIFO::*;

interface CounterIndication;
	method Action heard(Bit#(32) val);
endinterface

interface CounterRequest;
	method Action load(Bit#(32) newval);
	method Action increment();
endinterface

interface MyCounter;
	interface CounterRequest request;
endinterface


module mkMyCounter#(CounterIndication indication)(MyCounter);
	FIFO#(Bit#(32)) delay <- mkSizedFIFO(8);
	Reg#(Bit#(32)) value <- mkReg(0);

	rule respond;
		delay.deq;
		indication.heard(delay.first);
	endrule

	interface CounterRequest request;
		method Action load(Bit#(32) newval);
			value <= newval;
			delay.enq(newval);
		endmethod

		method Action increment();
			value <= value + 1;
			delay.enq(value+1);
		endmethod

	endinterface

endmodule
