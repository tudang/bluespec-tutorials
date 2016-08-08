BSV_FILE=TestBench.bsv
INTERFACE=sysTestBench

all: compile convert run

compile:
	bsc -u -verilog ${BSV_FILE}
convert:
	bsc -o sim -e ${INTERFACE} ${INTERFACE}.v
run:
	./sim
clean:
	rm -rf sim *.v *.bo xelab.*
