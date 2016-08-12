import Clocks::*;

(* synthesize *)
module mkTb(Empty);
	Reg#(int) counter <- mkReg(0);

	Clock c1 <- exposeCurrentClock();
	Reset r1 <- exposeCurrentReset();

	let clk_div <- mkClockDivider(4); 
	let c2 = clk_div.slowClock; 
	let r2 <- mkAsyncResetFromCR(0, c2); 

	Reg#(int) data1 <- mkReg(0, clocked_by c1, reset_by r1);
	Reg#(int) tst1 <- mkSyncReg(0, c1, r1, c2);
	Reg#(int) tst2 <- mkSyncReg(0, c2, r2, c1);

	rule loadtst1;
		tst1 <= data1;
	endrule

	rule loadtst2;
		tst2 <= tst1;
	endrule

	rule count;
		counter <= counter + 1;
	endrule

	rule end_sim(counter > 5);
		$finish;
	endrule
endmodule
