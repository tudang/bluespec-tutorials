package Tb;

(* synthesize *)
module mkTb();
    Reg#(int) x <- mkReg('h10);
    Reg#(int) pipe <- mkPipe;

    rule fill;
        pipe <= x;
        x <= x + 'h10;
    endrule

    rule drain;
        let y = pipe;
        $display(" y = %0h", y);
        if (y > 'h80) $finish(0);
    endrule
endmodule

interface Pipe_ifc;
    method Action send(int a);
    method int receive();
endinterface

(* synthesize *)
module mkPipe(Reg#(int));

    Reg#(Bool) valid1 <- mkReg(False); Reg#(int) x1 <- mkRegU;
    Reg#(Bool) valid2 <- mkReg(False); Reg#(int) x2 <- mkRegU;
    Reg#(Bool) valid3 <- mkReg(False); Reg#(int) x3 <- mkRegU;
    Reg#(Bool) valid4 <- mkReg(False); Reg#(int) x4 <- mkRegU;

    rule r1;
        valid2 <= valid1; x2 <= x1 + 1;
        valid3 <= valid2; x3 <= x2 + 1;
        valid4 <= valid3; x4 <= x3 + 1;
    endrule

    function Action display_Valid_value(Bool valid, int value);
        if (valid)  $write (" %0h", value);
        else        $write(" Invalid");
    endfunction

    rule show;
        $write(" x1, x2, x3, x4 =");
        display_Valid_value(valid1, x1);
        display_Valid_value(valid2, x2);
        display_Valid_value(valid3, x3);
        display_Valid_value(valid4, x4);
        $display("");
    endrule

    method Action _write(int a);
        valid1 <= True;
        x1 <= a;
    endmethod

    method int _read() if (valid4);
        return x4;
    endmethod

endmodule
endpackage