functor
import
    Connection2
    System
    Reflection at 'x-oz://boot/Reflection'
    OS

define
    C = {NewArray 0 9 unit}
    D = {NewArray 0 9 unit}
    Ready
    for I in 0..9 do
        {Put C I I*I}
        {Put D I I+10}
    end

    Ticket = {Connection2.offer C#D#Ready}

    {System.showInfo 'Please connect SampleClient to the following ticket, then press [Enter].'}
    {System.showInfo Ticket}

    {OS.read 0 1 _ nil _}

    {System.showInfo 'Wait until the client has changed the content of the arrays.'}
    {Wait Ready}

    {System.showInfo 'Now going to show content of arrays C and D.'}

    for I in 0..9 do
        {System.showInfo 'C['#I#'] = '#{Get C I}}
        {System.showInfo 'D['#I#'] = '#{Get D I}}
    end
end


