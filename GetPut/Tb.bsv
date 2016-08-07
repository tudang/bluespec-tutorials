import GetPut::*;

(* synthesize *)
module mkTb(Empty);
	GetPut#(int)  getput <- mkGPFIFO();
	Get#(int) geti = tpl_1(getput);
	Put#(int) puti = tpl_2(getput);
	Reg#(int) counter <- mkReg(0);

	rule add_item;
		puti.put(counter);
		$display("put an %d", counter);
	endrule

	rule get_item;
		let x <- geti.get();
		$display("get an %d", x);
	endrule

	rule count;
		counter <= counter + 1;
	endrule

	rule end_sim(counter > 5);
		$finish;
	endrule
endmodule

