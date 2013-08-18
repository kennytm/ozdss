functor
import
    Connection2
    System
    Reflection at 'x-oz://boot/Reflection'
    OS

define
    R = {NewCell 0}
    S
    T = r(S S R)

    {System.showInfo waiting}

    Ticket = {Connection2.offer T}

    {System.showInfo Ticket}

    {OS.read 0 1 _ nil _}

    {System.show T}

    {System.show @(T.3)}

    {Assign T.3 test}

end


