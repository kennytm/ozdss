functor
import
    Connection2
    System
    Open

define
    T = {Connection2.offer {NewCell 123}}

    F = {New Open.file init(name:'ticket.txt' flags:[write])}
    {F write(vs:T)}
    {F close}

    {System.show 'Waiting for client to connect to '#T}
end


