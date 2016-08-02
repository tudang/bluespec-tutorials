BSV_FILE=Tb.bsv
INTERFACE=Tb

all: compile convert run

compile:
	bsc -u -verilog ${BSV_FILE}
convert:
	bsc -o sim -e mk${INTERFACE} mk${INTERFACE}.v
run:
	./sim
clean:
	rm -rf sim *.v *.bo
