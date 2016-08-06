package Tb;

import FIFO::*;
import FIFOF::*;

(* synthesize *)
module mkTb (Empty);
	FIFOF#(Bit#(32)) fin <- mkFIFOF();
	Reg#(Bit#(32)) counter <- mkReg(0);

	(* descending_urgency = "add_element, drain" *)
	rule add_element (fin.notFull);
		fin.enq(counter);
		$display("[%0d] Enqueue: %0d", counter, counter);
	endrule

	rule drain (fin.notEmpty && counter > 3);
		fin.deq;
		let x = fin.first();
		$display("[%0d] Dequeue: %0d", counter, x);
	endrule

	rule incr_count;
		counter <= counter + 1;
	endrule

	rule end_sim (counter > 10);
		$finish;	
	endrule

endmodule
endpackage

