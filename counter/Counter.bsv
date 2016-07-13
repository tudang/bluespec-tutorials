import FIFO::*;

interface CounterIndication;
	method Action heard(Bit#(32) val);
endinterface

interface CounterRequest;
	method Action load(Bit#(32) newval);
	method Action increment();
endinterface

interface Counter;
	interface CounterRequest request;
endinterface


module mkCounter#(CounterIndication indication)(Counter);
	Reg#(Bit#(32)) value <- mkReg(0);
	PulseWire read_called <- mkPulseWire();

	rule heard(read_called);
		indication.heard(value);
	endrule

	interface CounterRequest request;
		method Action load(Bit#(32) newval);
			value <= newval;
			read_called.send();
		endmethod

		method Action increment();
			value <= value + 1;
		endmethod

	endinterface

endmodule
