functor
import
    Property
    UUID
    OS

export
    GetTicketPrefix
    ParseTicketURL
    MyPort
    MySiteID
    MyIP
    SetPort

define
    %%% Get the 'rank' of an IPv4 or v6 address. A higher-ranked IP has more
    %%% exposure to the network, thus more suitable as a site address.
    fun {GetIPRank IP}
        % 127.0.0.1/8 and ::1/128 can only be accessed locally (rank 0).
        % 169.254.0.0/16 and fe80::/10 are link-local (rank 2).
        % 10.0.0.0/8, 172.16.0.0/12 and 192.168.0.0/16 are private
        % fc00::/7 are unique-local (rank 4)
        % not caring about the rest. assume the IPv4 is better than IPv6.
        IPString = {VirtualString.toString IP}
    in
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
        else
            if {Member &: IPString} then 6 else 7 end
        end
    end

    %%% Obtain the IP address of this computer. Note that the result is usually
    %%% useless outside of the local network if the computer is behind a router.
    fun {GetLocalIP}
        AllAddr = "127.0.0.1" | {OS.getHostByName {OS.uName}.nodename}.addrList
        BestIP = {NewCell AllAddr.1}
        BestRank = {NewCell {GetIPRank AllAddr.1}}
    in
        for IP in AllAddr.2 do
            Rank = {GetIPRank IP}
        in
            if Rank > @BestRank then
                BestRank := Rank
                BestIP := IP
            end
        end
        % Check if we've got an IPv6 address. If yes, surround with '[' ... ']'.
        if @BestRank mod 2 == 0 then
            '['#@BestIP#']'
        else
            @BestIP
        end
    end

    %%% Get the IP (as a virtual string) used to broadcast this computer.
    fun {MyIP} @MyIPCell end

    %%% Get the unique identifier to identify this site in the machine. This
    %%% must be an atom.
    fun {MySiteID} @MyIdentifierCell end

    %%% Get the port used to access this site. This must be an integer.
    fun {MyPort} @MyPortCell end

    %%% Change the port used to access this site. If called, this method must be
    %%% placed before any DSS operations.
    proc {SetPort NewPortI} MyPortCell := NewPortI end

    %%% Get the prefix to a ticket on this site.
    fun {GetTicketPrefix}
        'oz-ticket://'#{MyIP}#':'#{MyPort}#'/tickets/'#{MySiteID}#'/'
    end

    proc {ParseTicketURL URL ?IP ?Port ?SiteID ?TicketID}
        IPPort
        TicketIDString
        IPString
        PortString
        SiteIDString
    in
        ["oz-ticket:" nil IPPort "tickets" SiteIDString TicketIDString] =
                {String.tokens {VirtualString.toString URL} &/}
        TicketID = {StringToInt TicketIDString}
        SiteID = {VirtualString.toAtom SiteIDString}
        if IPPort.1 == &[ then
            % IPv6.
            {String.token IPPort &] ?IPString ?PortString}
            IP = IPString#']'
            Port = {StringToInt PortString.2}
        else
            % IPv4
            {String.token IPPort &: ?IPString ?PortString}
            IP = IPString
            Port = {StringToInt PortString}
        end
    end

    %%% Define default settings for DP module
    MyIPCell = {NewCell {Property.condGet 'dss.ip' {GetLocalIP}}}
    MyIdentifierCell = {NewCell {Property.condGet 'dss.identifier' {VirtualString.toAtom {UUID.randomUUID}}}}
    MyPortCell = {NewCell {Property.condGet 'dss.port' 9000}}
end

