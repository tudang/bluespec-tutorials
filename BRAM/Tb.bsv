import BRAM::*;
import Clocks::*;
import DefaultValue::*;
import StmtFSM::*;

function BRAMRequest#(Bit#(8), Bit#(8)) makeRequest(Bool write, Bit#(8) addr, Bit#(8) data);
	return BRAMRequest {
		write : write,
		responseOnWrite : False,
		address : addr,
		datain : data
	};
endfunction

(* synthesize *)
module mkTb();
	BRAM_Configure cfg = defaultValue;
	cfg.allowWriteResponseBypass = False;
	BRAM2Port#(Bit#(8), Bit#(8)) dut0 <- mkBRAM2Server(cfg);
	cfg.loadFormat = tagged Hex "bram2.txt";
	BRAM2Port#(Bit#(8), Bit#(8)) dut1 <- mkBRAM2Server(cfg);

	Stmt test = 
	(seq
		delay(10);
		action
			dut1.portA.request.put(makeRequest(True, 8'h02, 8'h02));
			dut1.portB.request.put(makeRequest(True, 8'h03, 8'h03));
		endaction
		action
			dut1.portA.request.put(makeRequest(False, 8'h02, 0));
			dut1.portB.request.put(makeRequest(False, 8'h03, 0));
		endaction
		action
			$display("dut1read[0] = %x", dut1.portA.response.get);
			$display("dut1read[1] = %x", dut1.portB.response.get);
		endaction
		delay(100);
	endseq);
	mkAutoFSM(test);
endmodule
