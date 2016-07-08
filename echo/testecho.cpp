#include <errno.h>
#include <stdio.h>
#include "EchoIndication.h"
#include "EchoRequest.h"
#include "GeneratedTypes.h"

static EchoRequestProxy *echoRequestProxy = NULL;
static sem_t mutex;

class EchoIndication : public EchoIndicationWrapper
{
public:
	virtual void heard(uint32_t v) {
		printf("heard an echo: %d\n", v);
		sem_post(&mutex);
	}
	EchoIndication(unsigned int id) : EchoIndicationWrapper(id) {}
};

static void call_say(int v)
{
	printf("[%s:%d] %d\n", __FUNCTION__, __LINE__, v);
	echoRequestProxy->say(v);
	sem_wait(&mutex);
}

int main(int argc, char *argv[])
{
	long actualFrequency = 0;
	long requestedFrequency = 1e9 / MainClockPeriod;

	EchoIndication indication(IfcNames_EchoIndicationH2S);
	echoRequestProxy = new EchoRequestProxy(IfcNames_EchoRequestS2H);

	int status = setClockFrequency(0, requestedFrequency, &actualFrequency);
	fprintf(stderr, "Requested main clock frequency %5.2f, actual clock frequency \
					%5.2f  MHz. status=%d, errno=%d\n",
			(double)requestedFrequency * 1.0e-6,
			(double)actualFrequency * 1.0e-6,
			status, errno);

	int v = 42;
	printf("Saying %d\n", v);
	call_say(v);

	return 0;
}
