functor
import
    Connection2
    System
    DSSCommon
    Open

define

    {DSSCommon.setPort 9001}

    F = {New Open.file init(name:'ticket.txt')}
    T = {F read(list:$)}
    {F close}

    {System.show 'Going to connect to '#T}

    C = {Connection2.take T}
    {System.show 'Is it a cell? '#{IsCell C}}
    {System.show 'What\'s the content? '}
    {System.show @C}   % <--- now stuck here.
end



