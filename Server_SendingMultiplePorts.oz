functor
import
    Connection2
    System
    OS
    Pickle

define
    S1

    P1 = {NewPort S1}
    Ticket = {Connection2.offer P1}
    {Pickle.save Ticket 'master.tkt'}

    {System.showInfo 'Please start Client2 now.'}

    proc {PrintPairFromTwoStreams S1 S2}
        A B
    in
        {OS.read 0 1 _ nil _} % <-- Uncomment it to avoid 'stuck at markNeeded' problem. Need to press [Enter] to continue.
        A = S1.1
        B = S2.1
        {System.show [A B]}
        {PrintPairFromTwoStreams S1.2 S2.2}
    end

    for X in S1 do
        {System.show X}
        case X
        of test(S3 S4) then
            {PrintPairFromTwoStreams S3 S4}
        else
            {Exception.raiseError unknownMessage(X)}
        end
    end

end


