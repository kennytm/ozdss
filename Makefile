all: SampleClient.ozf SampleServer.ozf \
     Server_SendingMultiplePorts.ozf Client_SendingMultiplePorts.ozf  \
     Server_StuckAtMarkNeeded.ozf Client_StuckAtMarkNeeded.ozf

clean:
	rm -f *.ozf master.tkt ticket.txt

%.ozf: %.oz
	ozc -c $^

DSSCommon.oz: UUID.ozf

ReflectionEx.oz: ListEx.ozf LinearDictionary.ozf

Connection2.oz: DSSCommon.ozf ReflectionEx.ozf

SampleClient.oz: Connection2.ozf

SampleServer.oz: Connection2.ozf

Server_SendingMultiplePorts.oz: Connection2.ozf

Client_SendingMultiplePorts.oz: Connection2.ozf

Server_StuckAtMarkNeeded.oz: Connection2.ozf

Client_StuckAtMarkNeeded.oz: Connection2.ozf


