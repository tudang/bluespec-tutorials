import Vector::*;

(* synthesize *)
module mkTb();

    rule show;
        Vector#(16, bit) bar3 = unpack(16'b0101_0001_1000_1001);
        $display("reverse bar3 is %b", reverse(bar3));
        $display("bar 3 is        %b", bar3);
        $display("rotate1 bar3 is %b", rotate(bar3));
        $display("rotate2 bar3 is %b", rotate(rotate(bar3)));
        $display("rotateBy bar3is %b", rotateBy(bar3, 2));

        $finish(0);
    endrule
endmodule