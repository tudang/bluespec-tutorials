package Tb;

import StmtFSM::*;

(* synthesize *)
module mkTb (Empty);
	Stmt test =
	seq
		$display("I am now running at ", $time);
		$display("I an now running one more step at ", $time);
		$display("And now I will finish at ", $time);
	endseq;

	mkAutoFSM (test);

	rule run;
		$display(" and a rule fires at ", $time);
	endrule
endmodule
endpackage

