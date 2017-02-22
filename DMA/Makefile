BSV_FILE=TestBench.bsv
INTERFACE=sysTestBench
BSVFLAGS=-u -no-warn-action-shadowing
all: run

${INTERFACE$}.v: ${BSV_FILE}
	bsc ${BSVFLAGS} -verilog $<

sim: ${INTERFACE}.v
	bsc -o sim -e ${INTERFACE} $<

run: sim
	./sim

clean:
	rm -rf sim* *.v *.bo xsim.dir xelab* webtalk* xsim* .Xil
