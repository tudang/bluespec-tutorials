BSV_FILE=Tb.bsv
INTERFACE=Tb

all: run

mk${INTERFACE$}.v: ${BSV_FILE}
	bsc -verilog $<

sim: mk${INTERFACE}.v
	bsc -o sim -e mk${INTERFACE} $<

run: sim
	./sim

clean:
	rm -rf sim* *.v *.bo xsim.dir xelab* webtalk* xsim* .Xil
