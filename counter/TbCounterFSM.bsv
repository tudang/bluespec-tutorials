import StmtFSM::*;
import MyCounter::*;

(* synthesize *)
module mkTbCounterFSM();
	Counter#(Int#(20)) counter <- mkCounter();

	function check(expected_val);
		action
			if (counter.read() != expected_val) 
				$display("FAIL: counter != %0d", expected_val);
		endaction
	endfunction

	Stmt test_seq = seq
		counter.load(42);
		check(42);
		counter.increment(7);
		check(49);
		counter.decrement(20);
		check(29);
		$display("TEST FINISHED");
	endseq;

	mkAutoFSM(test_seq);
endmodule
