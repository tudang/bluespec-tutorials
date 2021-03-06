#include <errno.h>
#include <stdio.h>
#include "CounterIndication.h"
#include "CounterRequest.h"
#include "GeneratedTypes.h"

static CounterRequestProxy *counterRequestProxy = NULL;
static sem_t mutex;

class CounterIndication : public CounterIndicationWrapper
{
public:
	virtual void heard(uint32_t v) {
		printf("value=%d\n", v);
		sem_post(&mutex);
	}
	CounterIndication(unsigned int id) : CounterIndicationWrapper(id) {}
};

static void call_load(int v) {
	printf("[%s, %d] %d\n", __FUNCTION__, __LINE__, v);
	counterRequestProxy->load(v);
	sem_wait(&mutex);
}

static void call_increment() {
	printf("[%s, %d]\n", __FUNCTION__, __LINE__);
	counterRequestProxy->increment();
	sem_wait(&mutex);
}

int main(int argc, char *argv[])
{
	long actualFrequency = 0;
	long requestedFrequency = 1e9 / MainClockPeriod;

	CounterIndication indication(IfcNames_CounterIndicationH2S);
	counterRequestProxy = new CounterRequestProxy(IfcNames_CounterRequestS2H);

	int status = setClockFrequency(0, requestedFrequency, &actualFrequency);
	fprintf(stderr, "Requested main clock frequency %5.2f, actual clock frequency \
					%5.2f Mhz, status=%d, errno%d\n",
			(double)requestedFrequency * 1.0e-6,
			(double)actualFrequency * 1.0e-6,
			status, errno);

	int v = 42;

	call_load(v);
	call_increment();
	
	return 0;
}

