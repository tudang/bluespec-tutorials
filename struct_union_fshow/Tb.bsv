package Tb;

typedef enum {READ, WRITE, UKNOWN} OpCommand deriving(Bounded, Bits, Eq, FShow);

typedef struct {
	OpCommand command;
	Bit#(8)	addr;
	Bit#(8)	data;
	Bit#(8)	length;
	Bool	lock;
} Header deriving (Eq, Bits, Bounded);

typedef union tagged {
	Header	Descriptor;
	Bit#(8)	Data;
} Request deriving (Eq, Bits, Bounded);

instance FShow#(Header);
	function Fmt fshow(Header value);
		return ($format("<HEAD ")
		+ fshow(value.command)
		+ $format(" (%0d)", value.length)
		+ $format(" A:%h", value.addr)
		+ $format(" D:%h>", value.data));
	endfunction
endinstance

instance FShow#(Request);
	function Fmt fshow (Request request);
		case (request) matches
			tagged Descriptor .a: return fshow(a);
			tagged Data .a: return $format("<DATA %h>", a);
		endcase
	endfunction
endinstance

(* synthesize *)
module mkTb (Empty);

	rule start_sim;
		let rd = Header { command : READ, length: 27, addr: 254, data : 42, lock : False };
		let req1 = tagged Descriptor rd;
		let req2 = tagged Data 98;
		$display(fshow(rd));
		$display(fshow(req1));
		$display(fshow(req2));
		$finish;
	endrule

endmodule
endpackage

