functor

import
    OS
    SharedObjects
    StdEx

export
    SetLocalAddress
    GetLocalAddress

define
    %%% A ticket center is a class that "sells" tickets. This class hosts a
    %%% repository of objects, and associate URLs (tickets) to each of the
    %%% objects.
    class BoxOffice
        feat
            address
            port
            objects
            sharedObjects
            socket
            peers

        %%% Construct a new box office, published to the given address, and
        %%% listening on the given TCP port.
        meth init(address:Addr<=best port:P)
            self.address = (if Addr \= best then Addr else {FetchLocalAddress})
            self.port = P
            self.objects = {NewDictionary}
            self.sharedObjects = {New SharedObjects.sharedObjects init}
            self.socket = 0
            self.peers = {NewDictionary}

            /* TODO turn into Oz code.

            self.socket = {Socket.newServer self.port}
            thread
                for FD#OriginAddress in {self.socket accept} do
                    thread
                        {self runSocket(FD OriginAddress)}
                    end
                end
            end

            */
        end

        meth runSocket(FD OriginAddress)
            /* TODO turn into Oz code

            OriginPort = {StdEx.fromLittleEndianBytes {FD read(4)}}
            OriginName = {FD readName} % <- read a length and then deserialize into Name... sort of.

            if {Not {DictionaryContains self.peers OriginName}} then
                SendSocket = {Socket.connect OriginAddress OriginPort}

            end

            % ^ active messages will be sent to this socket.

            IsAlive = {NewCell true}
            IsConnected = {NewCell true}

            thread
                while @IsConnected do
                    if @IsAlive then
                        {self.sharedObjects setStatusForLink(link:OriginName status:ok)}
                        IsAlive := false
                    else
                        {self.sharedObjects setStatusForLink(link:OriginName status:tempFail)}
                    end
                    {Wait "some delay"}
                end
            end

            while true do
                % ^ break on error/disconnect.

                Tag = {FD read(4)}
                Length = {StdEx.fromLittleEndianBytes {FD read(4)}
                Content = {FD read(Length)}
                IsAlive := true

                case Tag

                of b"take" then
                    % Take object
                    assert Length == 4
                    TicketID = {StdEx.fromLittleEndianBytes Content}
                    if Result#IsShareOnce = {self.objects.condGet TicketID} then
                        Serialized = {Serializer.serialize Result OriginName self.sharedObjects}
                        {FD reply(b"shrd" # {Length Serialized} # Serialized)
                        if IsShareOnce then
                            {self.objects.remove TicketID}
                        end
                    else % <- get failure. need to turn it into case/of.
                        {FD reply(b"errr" # b"ntkt")}
                    end

                [] b"htbt" then
                    % Heartbeat, just skip.
                    skip

                [] b""

                else
                    {FD reply(b"errr" # b"unkn")}
                end
            end

            {self.sharedObjects disconnect(OriginName)}
            IsConnected := false

            */
            skip
        end

        meth share(obj:Object once:Onceness ticket:?TicketID)

        end

        meth take(address:Address port:Port ticket:TicketID obj:?Object)

        end
    end

    %%% Change the local address this site should be exposed to. This function
    %%% only affects how the ticket URL is formatted.
    proc {SetLocalAddress NewAddress}
        LocalAddress := NewAddress
    end

    %%% Obtains the local address this site is currently published to.
    fun {GetLocalAddress}
        @LocalAddress
    end

    %%% Change the local port this DSS instance should be listening on
    proc {SetLocalPort NewPort}
        LocalPort := NewPort
        /* TODO

        Destroy global TicketCenter
        Create new TicketCenter

        */
    end


    %%% Store the address of the current site. This address will be published to
    %%% the outside world.
    LocalAddress = {NewCell {FetchLocalAddress}}

    %%% Which port to open for others to use.
    LocalPort = {NewCell 9000}

    %%% Guess the local address which other sites can reach to. This should
    %%% return a virtual string, usually of the form "192.168.x.x".
    %%%
    %%% If an IPv6 address is chosen, the returned string will be in a pair of
    %%% brackets, like "[fe80::1234:5678]".
    fun {FetchLocalAddress}
        fun {MaxByRank A B}
            if A.1 > B.1 then A else B end
        end
        AllAddr = {OS.getHostByName {OS.uName}.nodename}.addrList
        RankedAddr = [{GetIPRank X}#X suchthat X in AllAddr]
        BestAddr = {FoldR RankedAddr MaxByRank 1#"127.0.0.1"}
        IsIPv6 = (BestAddr.1 mod 2 == 0)
    in
        if IsIPv6 then
            '['#BestAddr.2#']'
        else
            BestAddr.2
        end
    end

    %%% Obtain the "rank" of an IP address. The address with higher rank is
    %%% more favorable to the other sites.
    %%%
    %%% - All IPv6 address has even rank, and IPv4 has odd rank (+1).
    %%% - Loopback addresses (::1/128, 127.0.0.1/8) have ranks 0 and 1.
    %%% - Link-local addresses (fe80::/10, 169.254.0.0/16) have ranks 2 and 3.
    %%% - Unique-local addresses (fc00::/7, 10.0.0.0/8, 172.16.0.0/12,
    %%%   192.168.0.0/16) have ranks 4 and 5
    %%% - The rest are assumed to be world accessible and have ranks 6 and 7.
    fun {GetIPRank IP}
        IPString = {VirtualString.toString IP}
    in
        % We seriously need a regex library.
        case IPString
            of &1|&0|&.|_ then 5
            [] &1|&2|&7|&.|_ then 1
            [] &1|&6|&9|&.|&2|&5|&4|&.|_ then 3
            [] &1|&7|&2|&.|&1|&6|&.|_ then 5
            [] &1|&7|&2|&.|&1|&7|&.|_ then 5
            [] &1|&7|&2|&.|&1|&8|&.|_ then 5
            [] &1|&7|&2|&.|&1|&9|&.|_ then 5
            [] &1|&7|&2|&.|&2|_|&.|_ then 5
            [] &1|&7|&2|&.|&3|&0|&.|_ then 5
            [] &1|&7|&2|&.|&3|&1|&.|_ then 5
            [] &1|&9|&2|&.|&1|&6|&8|&.|_ then 5
            [] &F|&C|_|_|&:|_ then 4
            [] &F|&D|_|_|&:|_ then 4
            [] &F|&E|&8|_|&:|_ then 2
            [] &F|&E|&9|_|&:|_ then 2
            [] &F|&E|&A|_|&:|_ then 2
            [] &F|&E|&B|_|&:|_ then 2
            [] &f|&c|_|_|&:|_ then 4
            [] &f|&d|_|_|&:|_ then 4
            [] &f|&e|&8|_|&:|_ then 2
            [] &f|&e|&9|_|&:|_ then 2
            [] &f|&e|&a|_|&:|_ then 2
            [] &f|&e|&b|_|&:|_ then 2
            [] "::1" then 0
            else (if {Member &: IPString} then 6 else 7 end)
        end
    end


end

