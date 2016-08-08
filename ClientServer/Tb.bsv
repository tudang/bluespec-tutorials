import FIFO::*;
import ClientServer::*;
import GetPut::*;
import Connectable::*;

(* synthesize *)
module mkTb(Empty);
	Reg#(Bit#(32)) counter <- mkReg(0);
	Client#(Bit#(32), Bit#(64)) client <- mkClient;
	Server#(Bit#(32), Bit#(64)) server <- mkServer;

	mkConnection(client, server);

	rule count;
		counter <= counter + 1;
	endrule

	rule end_sim(counter > 15);
		$finish;
	endrule
endmodule


(* synthesize *)
module mkClient (Client#(Bit#(32), Bit#(64)));
	FIFO#(Bit#(32)) req <- mkFIFO;
	FIFO#(Bit#(64)) resp <- mkFIFO;

	Reg#(Bit#(32)) counter <- mkReg(0);


	rule client_submit_request;
		req.enq(counter);
		$display("submit %d", counter);
	endrule

	rule client_receive_response;
		resp.deq;
		let x = resp.first;
		$display("get response %h", x);
	endrule

	rule count;
		counter <= counter + 1;
	endrule


	interface Get request = toGet(req);
	interface Put response = toPut(resp);
endmodule

(* synthesize *)
module mkServer (Server#(Bit#(32), Bit#(64)));
	FIFO#(Bit#(32)) req <- mkFIFO;
	FIFO#(Bit#(64)) resp <- mkFIFO;
	Reg#(Bit#(32)) counter <- mkReg(0);

	rule server_handle_request;
		req.deq;
		let x = req.first;
		$display("concat {%h, %h}", x, x + 10);
		let y = {x, x+10};
		resp.enq(y);
	endrule

	rule count;
		counter <= counter + 1;
	endrule


	interface Put request = toPut(req);
	interface Get response = toGet(resp);

endmodule
