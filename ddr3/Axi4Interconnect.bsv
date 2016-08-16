// Axi4Interconnect.bsv
import Axi4MasterSlave::*; // Axi4 interface package from Connectal
import DefaultValue::*;
import FIFO::*;
import Vector::*;
import GetPut::*;

// Notes on the AXI Protocol
/////////////////////////////

// len = number of transfers per burst (0b00000000 -> 1 transfer per burst, 0b00000001 -> 2 transfers per burst, 0b11111111 -> 256 transfers per burst)
// size = burst size (0b000 -> 1 byte, 0b001 -> 2 bytes, 0b010 -> 4 bytes, 0b011 -> 8 bytes, 0b100 -> 16 bytes, and so on)
// burst = burst type (0b00 -> fixed (address doesn't change), 0b01 incr (address increments by transfer size), 0b10 wrap)
// prot = protection mode (bit 0 -> unprivleged (0) vs privleged access (1),
//                         bit 1 -> secure access (0) vs non-secure access (1),
//                         bit 2 -> data access (0) vs instruction access (1)) -- just information passed to slaves
// cache = memory type (lots of different modes, 0b0011 is normal non-cacheable bufferable)
// id = transaction id for ordering (transactions from same master with same id require ordering)
// lock = lock type (AXI3: 0b00 -> normal access, 0b01 -> exclusive access, 0b10 -> locked access, AXI4: 0b0 -> normal access, 0b1 -> exclusive access)
// qos = quality of service (hight number is higher priority)
// resp = read and write response (0b00 -> okay, 0b01 -> exclusive okay, 0b10 -> slave error, 0b11 -> decode error

// Default values for Axi4 requests and responses
//////////////////////////////////////////////////

instance DefaultValue#(Axi4ReadRequest#(addrWidth, idWidth));
  defaultValue = Axi4ReadRequest {
      address:    0,
      len:        8'b00000000,  // One burst per read
      size:       3'b011,       // 8 bytes - FIXME: assume matches bus width of Axi4Master
      burst:      2'b01,        // Incrementing burst
      prot:       3'b000,       // Unprivleged, secure, data access
      cache:      4'b0011,      // Normal non-cacheable bufferable memory
      id:         0,            // Single ID
      lock:       2'b00,        // Normal access
      qos:        4'b0000       // Don't participate in any QoS scheme
    };
endinstance

instance DefaultValue#(Axi4ReadResponse#(busWidth, idWidth));
  defaultValue = Axi4ReadResponse {
      data:   0,
      resp:   2'b00,    // Okay
      last:   1'b1,     // Last transfer for read data
      id:     0         // Single ID
    };
endinstance

instance DefaultValue#(Axi4WriteRequest#(addrWidth, idWidth));
  defaultValue = Axi4WriteRequest {
      address:    0,
      len:        8'b00000000,  // One burst per read
      size:       3'b011,       // 8 bytes - FIXME: assume matches bus width of Axi4Master
      burst:      2'b01,        // Incrementing burst
      prot:       3'b000,       // Unprivleged, secure, data access
      cache:      4'b0011,      // Normal non-cacheable bufferable memory
      id:         0,            // Single ID
      lock:       2'b00,        // Normal access
      qos:        4'b0000       // Don't participate in any QoS scheme
    };
endinstance

instance DefaultValue#(Axi4WriteData#(busWidth, idWidth));
  defaultValue = Axi4WriteData {
      data:         0,
      byteEnable:   '1,     // Write all bytes
      last:         1'b1,   // Last transfer for write data
      id:           0       // Single ID
    };
endinstance

instance DefaultValue#(Axi4WriteResponse#(idWidth));
  defaultValue = Axi4WriteResponse {
      resp:   2'b00,    // Okay
      id:     0         // Single ID
    };
endinstance

// Axi4FIFOs interface, modules, and functions
///////////////////////////////////////////////

interface Axi4FIFOs#(numeric type addrWidth, numeric type busWidth, numeric type idWidth);
  interface FIFO#(Axi4ReadRequest#(addrWidth, idWidth))   readReq;
  interface FIFO#(Axi4ReadResponse#(busWidth, idWidth))   readResp;
  interface FIFO#(Axi4WriteRequest#(addrWidth, idWidth))  writeReq;
  interface FIFO#(Axi4WriteData#(busWidth, idWidth))      writeData;
  interface FIFO#(Axi4WriteResponse#(idWidth))            writeResp;
endinterface

module mkAxi4FIFOs(Axi4FIFOs#(addrWidth, busWidth, idWidth));
  FIFO#(Axi4ReadRequest#(addrWidth, idWidth))   readReq_fifo <- mkFIFO;
  FIFO#(Axi4ReadResponse#(busWidth, idWidth))   readResp_fifo <- mkFIFO;
  FIFO#(Axi4WriteRequest#(addrWidth, idWidth))  writeReq_fifo <- mkFIFO;
  FIFO#(Axi4WriteData#(busWidth, idWidth))      writeData_fifo <- mkFIFO;
  FIFO#(Axi4WriteResponse#(idWidth))            writeResp_fifo <- mkFIFO;

  interface FIFO readReq = readReq_fifo;
  interface FIFO readResp = readResp_fifo;
  interface FIFO writeReq = writeReq_fifo;
  interface FIFO writeData = writeData_fifo;
  interface FIFO writeResp = writeResp_fifo;
endmodule

function Axi4Master#(addrWidth, busWidth, idWidth) toAxi4Master(Axi4FIFOs#(addrWidth, busWidth, idWidth) fifos);
  return (interface Axi4Master;
      interface req_ar = toGet(fifos.readReq);
      interface resp_read = toPut(fifos.readResp);
      interface req_aw = toGet(fifos.writeReq);
      interface resp_write = toGet(fifos.writeData);
      interface resp_b = toPut(fifos.writeResp);
    endinterface);
endfunction

function Axi4Slave#(addrWidth, busWidth, idWidth) toAxi4Slave(Axi4FIFOs#(addrWidth, busWidth, idWidth) fifos);
  return (interface Axi4Slave;
      interface req_ar = toPut(fifos.readReq);
      interface resp_read = toGet(fifos.readResp);
      interface req_aw = toPut(fifos.writeReq);
      interface resp_write = toPut(fifos.writeData);
      interface resp_b = toGet(fifos.writeResp);
    endinterface);
endfunction

// Axi4Interconnect
////////////////////

typedef struct {
  Vector#(numMasters, Axi4Slave#(addrWidth, busWidth, idWidth)) master_connectors;
  Vector#(numSlaves, Axi4Master#(addrWidth, busWidth, idWidth)) slave_connectors;
} Axi4Interconnect#(numeric type numMasters, numeric type numSlaves, numeric type addrWidth, numeric type busWidth, numeric type idWidth);

module mkAxi4Interconnect#(function Integer getSlaveIdxFromAddr(Bit#(addrWidth) addr)) (Axi4Interconnect#(numMasters, numSlaves, addrWidth, busWidth, idWidth));
  // FIFOs for inputs and outputs
  Vector#(numMasters,Axi4FIFOs#(addrWidth,busWidth,idWidth))  master_fifos  <- replicateM(mkAxi4FIFOs);
  Vector#(numSlaves,Axi4FIFOs#(addrWidth,busWidth,idWidth))   slave_fifos   <- replicateM(mkAxi4FIFOs);

  // Modules for arbitration
  FIFO#(Tuple2#(Bit#(TLog#(numMasters)), Bit#(TLog#(numSlaves))))  readArbiterFifo   <- mkFIFO;
  FIFO#(Tuple2#(Bit#(TLog#(numMasters)), Bit#(TLog#(numSlaves))))  writeArbiterFifo  <- mkFIFO;
  Vector#(numMasters,Reg#(Bool))  writeData_lock    <- replicateM(mkReg(False));

  for (Integer i = 0 ; i < valueOf(numMasters) ; i=i+1) begin
    rule readRequestArbitration;
      let x = master_fifos[i].readReq.first;
      let j = getSlaveIdxFromAddr(x.address);
      master_fifos[i].readReq.deq;
      slave_fifos[j].readReq.enq(x);
      // keep track of master that sent read request
      readArbiterFifo.enq(tuple2(fromInteger(i), fromInteger(j)));
    endrule

    rule writeRequestArbitration(readVReg(writeData_lock) == replicate(False));
      let x = master_fifos[i].writeReq.first;
      let j = getSlaveIdxFromAddr(x.address);
      slave_fifos[j].writeReq.enq(x);
      // keep track of master that sent write request
      writeArbiterFifo.enq(tuple2(fromInteger(i), fromInteger(j)));
      // hold lock until this master has sent all slave data
      writeData_lock[i] <= True;
    endrule

    rule writeDataArbitration(writeData_lock[i] == True);
      let x = master_fifos[i].writeData.first;
      let j = getSlaveIdxFromAddr(master_fifos[i].writeReq.first.address);
      master_fifos[i].writeData.deq;
      slave_fifos[j].writeData.enq(x);
      // if this is the last write data, release lock
      if (x.last == 1) begin
        writeData_lock[i] <= False;
        master_fifos[i].writeReq.deq;
      end
    endrule
  end

  for (Integer j = 0; j < valueOf(numSlaves) ; j=j+1) begin
    rule readResponseArbitration(tpl_2(readArbiterFifo.first) == fromInteger(j));
      let x = slave_fifos[j].readResp.first;
      slave_fifos[j].readResp.deq;
      let i = tpl_1(readArbiterFifo.first);
      master_fifos[i].readResp.enq(x);
      // if this is the last read data, dequeue this read from the read arbiter fifo
      if (x.last == 1) begin
        readArbiterFifo.deq;
      end
    endrule

    rule writeResponseArbitration(tpl_2(writeArbiterFifo.first) == fromInteger(j));
      let x = slave_fifos[j].writeResp.first;
      slave_fifos[j].writeResp.deq;
      let i = tpl_1(writeArbiterFifo.first);
      master_fifos[i].writeResp.enq(x);
      writeArbiterFifo.deq;
    endrule
  end

  Axi4Interconnect#(numMasters, numSlaves, addrWidth, busWidth, idWidth) interconnect;
  interconnect.master_connectors = map(toAxi4Slave, master_fifos);
  interconnect.slave_connectors = map(toAxi4Master, slave_fifos);
  return interconnect;
endmodule