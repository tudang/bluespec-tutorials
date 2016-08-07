package Tb;

import Memory::*;
import DefaultValue::*;


(* synthesize *)
module mkTb (Empty);
	Reg#(MemoryRequest#(64,32)) req <- mkReg(defaultValue);

	rule start_tb;
		MemoryRequest#(32,32) request = MemoryRequest { write: True, byteen: 'hf, address: 'h00112233, data: 'h55667788 };
		$display(fshow(req));
		$display(fshow(request));
		$finish;
	endrule
endmodule
endpackage

