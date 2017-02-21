package Tb;

import FIFO::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;

(* synthesize *)
module mkTb(Empty);
    Client#(int, int) stimulus_gen <- mkStimulusGen;
    Server#(int, int) dut <- mkDut;
    mkConnection (stimulus_gen, dut);
endmodule: mkTb

(* synthesize *)
module mkDut(Server#(int, int));
    FIFO#(int) f_in <- mkSizedFIFO(10);
    FIFO#(int) f_out <- mkSizedFIFO(10);

    rule compute;
        let x = f_in.first; f_in.deq;
        let y = x + 1;
        f_out.enq (y);
    endrule
    interface request = toPut(f_in);
    interface response = toGet(f_out);
endmodule: mkDut

(* synthesize *)
module mkStimulusGen(Client#(int, int));
    Reg#(int) x <- mkReg(0);
    FIFO#(int) f_out <- mkFIFO;
    FIFO#(int) f_in <- mkFIFO;
    FIFO#(int) f_expected <- mkFIFO;

    rule gen_stimulus;
        f_out.enq(x);
        x <= x + 10;
        f_expected.enq(x + 1);
    endrule

    rule check_results;
        let y = f_in.first; f_in.deq;
        let y_exp = f_expected.first; f_expected.deq;
        $display("(y, y_expected) = (%0d, %0d)", y, y_exp);
        if ( y == y_exp)
            $display(": PASSED");
        else
            $display(": FAILED");
        if (y_exp > 50) $finish(0);
    endrule


    function Client#(req_t, resp_t) fifosToClient(FIFO#(req_t) f_reqs,
                                    FIFO#(resp_t) f_resps);
    return interface Client
                interface request = toGet(f_reqs);
                interface response = toPut(f_resps);
            endinterface;
    endfunction: fifosToClient

    return fifosToClient(f_out, f_in);

endmodule



endpackage