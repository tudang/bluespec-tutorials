package Tb;

typedef enum { IDLE, PHASE1A, PHASE1B, PHASE2A, PHASE2B, ACCEPT, VALUE_ERROR, FINISH } State deriving (Bits, Eq);

(* synthesize *)
module mkTb (Empty);
	Reg#(State) state <- mkReg(IDLE);
	Reg#(Bool) init <- mkReg(False);
	Reg#(Bool) recv1b <- mkReg(False);
	Reg#(Bool) recv2b <- mkReg(False);
	Reg#(Bit#(256)) value <- mkReg('1);
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
		let ret <- paxos.handle2B(1, value);
		if (ret != IDLE)
			recv2b <= False;
		state <= ret;
	endrule

	rule stateFinish (state == FINISH);
		$display("Paxos has finished");
		$finish;
	endrule

	rule stateError (state == VALUE_ERROR);
		$display("Accepted values are different");
		$finish;
	endrule
endmodule: mkTb

interface PaxosIfc;
	method ActionValue#(Tuple3#(State, Maybe#(int), Maybe#(Bit#(256)))) handle1A(int bal);
	method ActionValue#(State) handle1B(int bal);
	method ActionValue#(State) handle2A(int bal, Bit#(256) val);
	method ActionValue#(State) handle2B(int bal, Bit#(256) val);
endinterface: PaxosIfc

(* synthesize *)
module mkPaxos#(parameter int init_ballot, parameter int qsize)(PaxosIfc);
	Reg#(int) ballot <- mkReg(init_ballot);
	Reg#(int) quorum <- mkReg(qsize);
	Reg#(int) vballot <- mkRegU;
	Reg#(Bit#(256)) value <- mkRegU;
	Reg#(int) count1b <- mkReg(0);
	Reg#(int) count2b <- mkReg(0);


	method ActionValue#(Tuple3#(State, Maybe#(int), Maybe#(Bit#(256)))) handle1A(int bal);
		State ret = IDLE;
		Maybe#(int) vbal = tagged Invalid;
		Maybe#(Bit#(256)) val = tagged Invalid;
		if (bal >= ballot) begin
			ballot <= bal;
			vbal = tagged Valid vballot;
			val = tagged Valid value;
		end
		return tuple3(IDLE, vbal, val);
	endmethod

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

	method ActionValue#(State) handle2A(int bal, Bit#(256) val);
		State ret = IDLE;
		if (bal >= ballot) begin
			ballot <= bal;
			vballot <= bal;
			value <= val;
			ret = ACCEPT;
		end
		return ret;
	endmethod

	method ActionValue#(State) handle2B(int bal, Bit#(256) val);
		State ret = IDLE;
		if (bal >= ballot) begin
			if ((value != 'haaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)
				&& (value != val)) begin
				ret = VALUE_ERROR;
			end
			else begin
				ballot <= bal;
				vballot <= bal;
				value <= val;
				if (count2b == quorum - 1) begin
					count2b <= count2b + 1;
					ret = FINISH;
				end
				else begin
					count2b <= count2b + 1;
				end
			end
		end
		return ret;
	endmethod
endmodule: mkPaxos

endpackage: Tb
