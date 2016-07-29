package Tb;

(* synthesize *)
module mkTb (Empty);

	rule greet;
		$display ("Hello World!");
		$finish (0);
	endrule
endmodule: mkTb
endpackage
