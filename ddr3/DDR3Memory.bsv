import Clocks::*;
import DefaultValue::*;
import Types::*;
import ClientServer::*;
import DRAMController::*;
import GetPut::*;
import FIFO::*;
import MemoryTypes::*;
import RegFile::*;
import Vector::*;
import XilinxVC709DDR3::*;

(* synthesize *)
module mkDDR3Memory(WideMem);
	//// DDR3 stuff start ////
	ClockGenerator7Params clk_params = defaultValue();
	clk_params.clkin1_period = 5.000;	// 200 Mhz reference
	clk_params.clkin_buffer = False;
	clk_params.reset_stages = 0;
	clk_params.clkfbout_mult_f = 5.000;
	clk_params.clkout0_divide_f = 10;	// unused clock
	clk_params.clkout1_divide = 5;		// ddr3 reference clock (200 MHz)

	ClockGenerator7 clk_gen <- mkClockGenerator7(clk_params,
						clocked_by sys_clk,
						reset_by pci_sys_reset_n);

	Clock ddr_clk = clk_gen.clkout0;
	Reset rst_n <- mkAsyncReset(4, pci_sys_reset_n, ddr_clk);
	DDR3_Configure ddr3_cfg = defaultValue;
	ddr3_cfg.reads_in_flight = 24;
	DDR3_Controller_VC709 ddr3_ctrl <- mkDDR3Controller_VC709(ddr3_cfg,
						clk_gen.clkout1,
						clocked_by clk_gen.clkout1,
						reset_by ddr3ref_rst_n);

	Clock ddr3clk = ddr3_ctrl.user.clock;
	Reset ddr3rstn = ddr3_ctrl.user.reset_n;
	DRAMControllerIfc dramController <- mkDRAMController(ddr3_ctrl.user,
						clocked_by,
						ddr_clk,
						reset_by rst_n);

	//// DDR3 stuff end ////

	Fifo#(1, WideMemResp) hitQ <- mkBypassFifo;
	Fifo#(1, WideMemResp) hitQ_host <- mkBypassFifo;

	interface Server to_proc;
		interface Put request;
			method Action put(wideMemReq r);
				if (r.op == St)
					dramController.write(r.addr, zeroExtend(data), 8);
				else
					dramController.readReq(r.addr, 8);
			endmethod
		endinterface

		interface Get response;
			method ActionValue#(WideMemResp) get();
				let d <- dramController.read;
				return truncate(d);
			endmethod
		endinterface
	endinterface

	interface Server to_host;
		interface Put request;
			method Action put(WideMemReq r);
				Bit#(22) index = truncate( r.addr >> valueOf(WideIndxShamt));

				let data = mem.sub(index);

				if (r.op == St)
				begin
					Vector#(WideNumBytes, Bit#(8)) bytes = unpack(data);
					Vector#(WideNumBytes, Bit#(8)) bytesIn = unpack(r.data);
					for (Integer i = 0; i < valueOf(WideNumBytes); i = i + 1)
					begin
						if (r.bytesEn[i])
							bytes[i] = bytesIn[i];
					end
					mem.upd(index, pack(bytes));
				end

				hitQ_host.enq(data);
			endmethod
		endinterface

		interface Get response;
			method ActionValue#(WideMemResp) get();
				hitQ_host.deq;
				return hitQ_host.first;
			endmethod
		endinterface
	endinterface
endmodule
		
