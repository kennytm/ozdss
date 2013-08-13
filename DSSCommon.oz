functor
import
    Property
    UUID
    OS
    System

export
    Init
    GetTicketPrefix
    MyPort
    MySiteID
    MyIP

define
    %%% Define default settings for DP module
    proc {Init}
        {Property.put 'dp.firewalled' false}
        {Property.put 'dss.ip' {GetLocalIP}}
        {Property.put 'dss.identifier' {UUID.randomUUID}}
        {Property.put 'dss.port' 9000}
    end

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

    %%% Find the maximum of list L, ordered by the keying function K.
    fun {MaxBy L K}
        MaxElem = {NewCell L.1}
        MaxKey = {NewCell {K L.1}}
    in
        for Elem in L.2 do
            Key = {K Elem}
        in
            if Key > @MaxKey then
                MaxKey := Key
                MaxElem := Elem
            end
        end
        @MaxElem
    end

    %%% Obtain the IP address of this computer. Note that the result is usually
    %%% useless outside of the local network if the computer is behind a router.
    fun {GetLocalIP}
        % What if this list is empty?
        AllAddr = {OS.getHostByName {OS.uName}.nodename}.addrList
    in
        {MaxBy AllAddr GetIPRank}
    end

    %%% Get the IP used to broadcast this computer.
    fun {MyIP}
        {Property.get 'dss.ip'}
    end

    %%% Get the unique identifier to identify this site in the machine.
    fun {MySiteID}
        {Property.get 'dss.identifier'}
    end

    %%% Get the port used to access this site.
    fun {MyPort}
        {Property.get 'dss.port'}
    end

    %%% Get the prefix to a ticket on this site.
    fun {GetTicketPrefix}
        'oz-ticket://'#{MyIP}#':'#{MyPort}#'/tickets/'#{MySiteID}#'/'
    end
end

