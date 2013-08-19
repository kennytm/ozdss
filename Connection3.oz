functor
import
    Connection2
    System
    Reflection at 'x-oz://boot/Reflection'
    OS

define
    R = {NewCell 7890}
    S
    T = R

    {System.showInfo waiting}

    Ticket = {Connection2.offer R}

    {System.showInfo Ticket}

    {OS.read 0 1 _ nil _}

    {Time.delay 1000}

    {System.show T}

    {System.show {Access T}}

    {Assign T test}

end


