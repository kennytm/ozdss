functor

import
    OS
    System
    StdEx

export
    Tags
    Server

define
    Accept = {NewName}

    %%% A list of tags to identify messages.
    Tags = r(
        take: 0x306b6174        % 'tak0'
        offer: 0x3052464f       % 'OFR0'
        ping: 0x30676e70        % 'png0'
        pong: 0x30474e50        % 'PNG0'
        finalized: 0x306e6966   % 'fin0'
    )

    class Server
        feat
            acceptor
            port
            callbacks

        %%% Create a new server
        meth init(ipVersion:IPVersion<=4 port:PortSpec)
            PortMin#PortMax = case PortSpec
                of exact(N) then N#N
                [] 'from'(N) then N#65535
                % [] free then 0#0   % TODO need to get port num from acceptor
            end
            Acceptor#PortNum = {CreateServer IPVersion PortMin PortMax}
        in
            self.acceptor = Acceptor
            self.port = PortNum
            self.callbacks = {NewDictionary}

            thread
                for do
                    {self Accept}
                end
            end
        end

        meth addCallback(tag:Tag function:F)
            {Dictionary.put self.callbacks Tag F}
        end

        meth sendTo(address:Address port:PortNum tag:Tag payload:Payload reply:?Reply)
            Connection = {OS.tcpConnect Address PortNum}
            PayloadLength = {VirtualByteString.length Payload}
            Message = {StdEx.toLittleEndianBytes Tag}#{StdEx.toLittleEndianBytes PayloadLength}#Payload
        in
            _ = {OS.tcpConnectionWrite Connection Message}

        end

        meth !Accept
            Connection = {OS.tcpAccept self.acceptor}
            thread
                try
                    {ProcessMessage Connection self.callbacks}
                catch E then
                    % Not sure how to deal with exceptions, but rethrowing will
                    % crash the VM.
                    {System.show "Exception happened while reading:"}
                    {System.show E}
                finally
                    % TODO Keep the connection alive?
                    {OS.tcpConnectionClose Connection}
                end
            end
        end
    end

    %%% Create a TCP server, trying all ports in the given range.
    fun {CreateServer IPVersion PortMin PortMax}
        Result = for return:R PortNum in PortMin..PortMax do
            try Acceptor in
                Acceptor = {OS.tcpAcceptorCreate IPVersion PortNum}
                {R ok(Acceptor PortNum)}
            catch E = system(os(os tcpAcceptorCreate ...) ...) then
                if PortNum == PortMax then
                    {R failure(E)}
                end
            end
        end
    in
        case Result
            of ok(Acceptor PortNum) then Acceptor#PortNum
            [] failure(E) then raise E end
        end
    end

    %%% Read exactly N bytes from the TCP connection. Returns a virtual byte
    %%% string if successful.
    fun {ReadExactly Connection N}
        Result
        PrevTail = {NewCell Result}
        Remaining = {NewCell N}
    in
        for while:@Remaining > 0 do
            Head Tail ReadCount
        in
            {OS.tcpConnectionRead Connection @Remaining ?Head Tail ?ReadCount}
            Remaining := @Remaining - ReadCount
            @PrevTail = Head
            PrevTail := Tail
        end
        @PrevTail = nil
        Result
    end


    proc {ProcessMessage Connection CallbacksDictionary}
        Tag = {StdEx.fromLittleEndianBytes {ReadExactly Connection 4}}
        Callback = {Dictionary.condGet CallbacksDictionary Tag unit}
    in
        if Callback \= unit then
            PayloadLength = {StdEx.fromLittleEndianBytes {ReadExactly Connection 4}}
            Payload = {ReadExactly Connection PayloadLength}
            Reply = {Callback Payload}
        in

        end
                        Tag Callback
                in
                    Tag = {StdEx.fromLittleEndianBytes {ReadExactly Connection 4}}
                    Callback = {Dictionary.condGet self.callbacks Tag unit}
                    if Callback \= unit then
                        PayloadLength =
                        Payload = {ReadExactly Connection Len}
                    in
                        Reply = {Callback Payload}
                        if Reply \= unit then
                            {Connection
                        end
                    end

    end
end

