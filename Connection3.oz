functor
import
    Connection2
    System

define
    R = {NewCell 0}
    S
    T = r(S S R)

    {System.showInfo waiting}

    Ticket = {Connection2.offer T}

    {System.showInfo Ticket}

    {Time.delay 10000}

    {System.show T}
end


