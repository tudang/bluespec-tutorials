(* synthesize *)
module mkTb();
    Reg#(int) x <- mkReg(5);
    Reg#(int) y <- mkReg(1);
    Reg#(int) z <- mkReg(2);
    Reg#(Bit#(4)) cycle <- mkReg(0);


    rule count_cycle;
        cycle <= cycle + 1;
    endrule

    function td add2x( td i, td j) provisos (Arith#(td));
        return ( i + 2*j );
    endfunction


    function Bool i2xj(td i, td j) provisos (Arith#(td), Eq#(td));
        return ( (i - 2*j) == 0);
    endfunction

    rule show;
        $display("cycle = %0d, &cycle = %0d, |cycle=%0d, ^cycle=%0d", cycle, &cycle, |cycle, ^cycle);
        if (cycle == 15)
            $finish(0);
    endrule
endmodule

module mkPlainReg( Reg#(tx) ) provisos (Bits#(tx, szTX));
    Reg#(tx) val <- mkRegU;
    return val;
endmodule