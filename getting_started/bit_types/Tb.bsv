package Tb;

(* synthesize *)
module mkTb(Empty);

  Reg#(int) step <- mkReg(0);

  Reg#(Int#(16)) int16 <- mkReg('h800);
  Reg#(UInt#(16)) uint16 <- mkReg('h800);

  rule step0 ( step == 0 );
    $display(" == step 0 ==");

    UInt#(16) foo = 'h1fff;
    $display("foo = %x", foo);

    foo = foo & 5;
    $display("foo = %x", foo);

    foo = 'hffff;
    $display("foo = %x", foo);

    foo = foo + 1;
    $display("foo = %x", foo);

    $display("fooneg = %x", foo < 0);

    UInt#(16) maxUInt16 = unpack('1);
    UInt#(16) minUInt16 = unpack(0);

    $display("maxUInt16 = %x", maxUInt16);
    $display("minUInt16 = %x", minUInt16);

    $display("%x < %x == %x (unsigned)", minUInt16, maxUInt16, minUInt16 < maxUInt16);
    step <= step + 1;

  endrule

  rule step1( step == 1);
    $display(" == step 1 ==");
    Int#(16) maxInt16 = unpack({1'b0,'1});
    Int#(16) minInt16 = unpack({1'b1, '0});
    $display("maxUInt16 = %x", maxInt16);
    $display("minUInt16 = %x", minInt16);

    $display("%x < %x == %x (unsigned)", minInt16, maxInt16, minInt16 < maxInt16);

    $display("maxInt16/4 = %x", maxInt16 / 4);
    int16 <= int16 / 4;
    step <= step + 1;
    endrule

  rule step2( step == 2);
    $display(" == step 2 ==");
    $finish(0);
  endrule
endmodule

endpackage

