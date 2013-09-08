functor
import
    Connection2
    System
    DSSCommon
    Pickle
    Open

define
    S1 S2

    P1 = {NewPort S1}
    P2 = {NewPort S2}

    {DSSCommon.setPort 9001}

    F = {New Open.file init(name:'master.tkt')}
    VBS = {F read(list:$)}
    {F close}

    Ticket = {Pickle.unpack VBS}

    {System.show 'Going to connect to '#Ticket}

    C = {Connection2.take Ticket}

    {Send C test(S1 S2)}

    {System.show 'Going to send numbers to the ports'}

    proc {DoSend}
        % First batch of message
        {Send P1 1}
        {Send P2 2}

        % Second batch of message.
        {Send P2 3}
        {Send P1 4}
    end

    {DoSend}
end



