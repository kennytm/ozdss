functor

import
    OS

export
    GetLocalAddress
    SetLocalAddress

define
    %%% Change the local address this site should be exposed to. This function
    %%% only affects how the ticket URL is formatted.
    proc {SetLocalAddress IPVersion NewAddress}
        LocalAddress := IPVersion#NewAddress
    end

    %%% Obtains the local address this site is currently published to. This
    %%% should return a pair of IP version and an atom, e.g.
    %%% 4#'192.168.1.100' or 6#'fe80::1234:5678'.
    fun {GetLocalAddress}
        @LocalAddress
    end

    %%% Store the address of the current site. This address will be published to
    %%% the outside world.
    LocalAddress = {NewCell {FetchLocalAddress}}


    %%% Guess the local address which other sites can reach to. This should
    %%% return a pair of IP version and an atom, e.g. 4#'192.168.1.100' or
    %%% 6#'fe80::1234:5678'.
    fun {FetchLocalAddress}
        AllAddr = {OS.getHostByName {OS.uName}.nodename}.addrList
        RankedAddr = {Map AllAddr (fun {$ X} {GetIPRank X}#X end)} % doesn't work -> % [{GetIPRank X}#X suchthat X in AllAddr]
        (IPVersion#_)#BestAddr = {FoldR RankedAddr BetterIPRank (4#0)#"127.0.0.1"} in
        IPVersion#{VirtualString.toAtom BestAddr}
    end

    fun {BetterIPRank A B}
        IPvA#RankA = A.1
        IPvB#RankB = B.1 in
        if RankA > RankB then
            A
        elseif RankA < RankB then
            B
        elseif IPvA < IPvB then
            A
        else
            B
        end
    end

    %%% Obtain the "rank" and IP version of an IP address. The address with
    %%% higher rank is more favorable to the other sites.
    %%%
    %%% - Loopback addresses (::1/128, 127.0.0.1/8) have rank 0.
    %%% - Link-local addresses (fe80::/10, 169.254.0.0/16) have rank 1.
    %%% - Unique-local addresses (fc00::/7, 10.0.0.0/8, 172.16.0.0/12,
    %%%   192.168.0.0/16) have ranks 2
    %%% - The rest are assumed to be world accessible and have rank 3.
    fun {GetIPRank IP}
        IPString = {VirtualString.toString IP} in
        % We seriously need a regex library.
        case IPString
            of &1|&0|&.|_ then 4#2
            [] &1|&2|&7|&.|_ then 4#0
            [] &1|&6|&9|&.|&2|&5|&4|&.|_ then 4#1
            [] &1|&7|&2|&.|&1|&6|&.|_ then 4#2
            [] &1|&7|&2|&.|&1|&7|&.|_ then 4#2
            [] &1|&7|&2|&.|&1|&8|&.|_ then 4#2
            [] &1|&7|&2|&.|&1|&9|&.|_ then 4#2
            [] &1|&7|&2|&.|&2|_|&.|_ then 4#2
            [] &1|&7|&2|&.|&3|&0|&.|_ then 4#2
            [] &1|&7|&2|&.|&3|&1|&.|_ then 4#2
            [] &1|&9|&2|&.|&1|&6|&8|&.|_ then 4#2
            [] &F|&C|_|_|&:|_ then 6#2
            [] &F|&D|_|_|&:|_ then 6#2
            [] &F|&E|&8|_|&:|_ then 6#1
            [] &F|&E|&9|_|&:|_ then 6#1
            [] &F|&E|&A|_|&:|_ then 6#1
            [] &F|&E|&B|_|&:|_ then 6#1
            [] &f|&c|_|_|&:|_ then 6#2
            [] &f|&d|_|_|&:|_ then 6#2
            [] &f|&e|&8|_|&:|_ then 6#1
            [] &f|&e|&9|_|&:|_ then 6#1
            [] &f|&e|&a|_|&:|_ then 6#1
            [] &f|&e|&b|_|&:|_ then 6#1
            [] "::1" then 6#0
            else (if {Member &: IPString} then 6 else 4 end)#3
        end
    end
end
