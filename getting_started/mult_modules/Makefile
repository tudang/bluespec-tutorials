BSV_FILE=Tb.bsv
INTERFACE=ModuleDeepThought

all: compile convert run

compile:
	bsc -verilog ${BSV_FILE}
convert:
	bsc -o sim -e mk${INTERFACE} mk${INTERFACE}.v
run:
	./sim
clean:
	rm -rf sim *.v *.bo
