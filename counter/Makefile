#BSV_FILE=TbCounter.bsv
BSV_FILE=TbCounterFSM.bsv
INTERFACE=TbCounterFSM

all: compile convert run

compile:
	bsc -u -verilog ${BSV_FILE}
convert:
	bsc -o sim -e mk${INTERFACE} mk${INTERFACE}.v
run:
	./sim
clean:
	rm -rf sim *.v *.bo
