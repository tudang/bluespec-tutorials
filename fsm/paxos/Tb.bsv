package Tb;

typedef enum { IDLE, PHASE1A, PHASE1B, PHASE2A, PHASE2B, FINISH } State deriving (Bits, Eq);

(* synthesize *)
module mkTb (Empty);
	Reg#(State) state <- mkReg(IDLE);
	Reg#(Bool) init <- mkReg(False);
	Reg#(Bool) recv1b <- mkReg(False);
	Reg#(Bool) recv2b <- mkReg(False);
	PaxosIfc paxos <- mkPaxos(1, 2);

	rule stateIdle ( state == IDLE );
		if (!init) begin
			$display("Start phase 1");
			init <= True;
			state <= PHASE1A;
		end
		else if (recv1b) begin
			state <= PHASE1B;
		end
		else if (recv2b) begin
			state <= PHASE2B;
		end
	endrule

	rule statePhase1A (state == PHASE1A);
		state <= IDLE;
		recv1b <= True;
		recv2b <= False;
	endrule

	rule statePhase1B (state == PHASE1B);
		$display("Received Phase1B messages");
		let ret <- paxos.handle1B(1);
		state <= ret;
	endrule

	rule  statePhase2A (state == PHASE2A);
		$display("Sent Phase2A messages");
		state <= IDLE;
		recv1b <= False;
		recv2b <= True;
	endrule

	rule statePhase2B (state == PHASE2B);
		$display("Received Phase2B messages");
		let ret <- paxos.handle2B(1);
		state <= ret;
	endrule

	rule stateFinish (state == FINISH);
		$display("Paxos has finished");
		$finish;
	endrule
endmodule: mkTb

interface PaxosIfc;
	method ActionValue#(State) handle1B(int bal);
	method ActionValue#(State) handle2B(int bal);
endinterface: PaxosIfc

(* synthesize *)
module mkPaxos#(parameter int init_ballot, parameter int qsize)(PaxosIfc);
	Reg#(int) ballot <- mkReg(init_ballot);
	Reg#(int) quorum <- mkReg(qsize);
	Reg#(int) vballot <- mkReg(0);
	Reg#(int) count1b <- mkReg(0);
	Reg#(int) count2b <- mkReg(0);


	method ActionValue#(State) handle1B(int bal);
		State ret = IDLE;
		if (bal >= ballot) begin
			ballot <= bal;
			if (count1b == quorum - 1) begin
				count1b <= count1b + 1;
				ret = PHASE2A;
			end
			else begin
				count1b <= count1b + 1;
			end
		end
		return ret;
	endmethod

	method ActionValue#(State) handle2B(int bal);
		State ret = IDLE;
		if (bal >= ballot) begin
			ballot <= bal;
			vballot <= bal;
			if (count2b == quorum - 1) begin
				count2b <= count2b + 1;
				ret = FINISH;
			end
			else begin
				count2b <= count2b + 1;
			end
		end
		return ret;
	endmethod
endmodule: mkPaxos

endpackage: Tb