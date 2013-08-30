all: SampleClient.ozf SampleServer.ozf

clean:
	rm -f *.ozf

%.ozf: %.oz
	ozc -c $^

DSSCommon.oz: UUID.ozf

ReflectionEx.oz: ListEx.ozf LinearDictionary.ozf

Connection2.oz: DSSCommon.ozf ReflectionEx.ozf

SampleClient.oz: Connection2.ozf

SampleServer.oz: Connection2.ozf


