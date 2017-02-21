package Tb;

import FIFO::*;

(* synthesize *)
module mkTb(Empty);

    Client_int stimulus_gen <- mkStimulusGen;
    Server_int dut <- mkDut;

    rule connect_reqs;
        let req <- stimulus_gen.get_request.get();
        dut.put_request.put(req);
    endrule

    rule connect_resps;
        let resp <- dut.get_response.get();
        stimulus_gen.put_response.put(resp);
    endrule
endmodule: mkTb

interface Put_int;
    method Action put(int x);
endinterface

interface Get_int;
    method ActionValue#(int) get();
endinterface

interface Client_int;
    interface Get_int get_request;
    interface Put_int put_response;
endinterface

interface Server_int;
    interface Put_int put_request;
    interface Get_int get_response;
endinterface

(* synthesize *)
module mkDut(Server_int);
    FIFO#(int) f_in <- mkSizedFIFO(10);
    FIFO#(int) f_out <- mkSizedFIFO(10);

    rule compute;
        let x = f_in.first; f_in.deq;
        let y = x + 1;
        if (x == 20) y = y + 1;
        f_out.enq (y);
    endrule

    interface Put_int put_request;
        method Action put(int x);
            f_in.enq(x);
        endmethod
    endinterface

    interface Get_int get_response;
        method ActionValue#(int) get();
            f_out.deq; return f_out.first;
        endmethod
    endinterface
endmodule: mkDut

(* synthesize *)
module mkStimulusGen(Client_int);
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

    interface get_request = interface Get_int;
                                method ActionValue#(int) get();
                                    f_out.deq; return f_out.first;
                                endmethod
                            endinterface;

    interface Put_int put_response;
        method Action put (int y) = f_in.enq(y);
    endinterface
endmodule



endpackage