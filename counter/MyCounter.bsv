interface Counter#(type t);
	method t read();
	method Action load(t newval);
	method Action increment(t di);
	method Action decrement(t dd);
endinterface

module mkCounter(Counter#(t))
	provisos(Arith#(t), Bits#(t, t_sz));
	Reg#(t) value <- mkReg(0);
	RWire#(t) incr <- mkRWire;
	RWire#(t) decr <- mkRWire;

	rule doit;
		Maybe#(t) mbi = incr.wget();
		Maybe#(t) mbd = decr.wget();

		case (tuple2(mbi, mbd)) matches
			{ tagged Invalid, tagged Invalid } : noAction; 
			{ tagged Valid .i, tagged Invalid } : value <= value + i;
			{ tagged Invalid, tagged Valid .d } : value <= value - d;
			{ tagged Valid .i, tagged Valid .d } : value <= value + i - d;
		endcase
	endrule


	method t read();
		return value;
	endmethod

	method Action load(t newval);
		value <= newval;
	endmethod

	method Action increment(t di);
		incr.wset(di);
	endmethod

	method Action decrement(t dd);
		decr.wset(dd);
	endmethod
endmodule
