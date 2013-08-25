functor
import
    Connection2
    System
    Property
    DSSCommon
    OS
    Application

define
    {DSSCommon.setPort 9001}

    Args = {Application.getArgs plain}
    Ticket

    case Args
    of T|_ then
        Ticket = T
    else
        {System.showInfo 'Usage: ozengine SampleClient.ozf [Ticket]'}
        {Application.exit 0}
    end

    C#D#Ready = {Connection2.take Ticket}

    {System.show 'We should receive two arrays: '#{IsArray C}#', '#{IsArray D}}

    {System.show 'Bounds of the array C: ['#{Array.low C}#', '#{Array.high C}}
    {System.show 'Bounds of the array D: ['#{Array.low D}#', '#{Array.high D}}

    {System.show 'Now we try to exchange the content of the two arrays.'}

    for I in {Array.low C}..{Array.high C} do
        CVal
        DVal
    in
        {System.show I}
        CVal = {Get C I}
        {System.show 'Old value of C['#I#'] = '#CVal}
        {Array.exchange D I ?DVal CVal}
        {System.show 'Old value of D['#I#'] = '#DVal}
        {Put C I DVal}
    end

    {System.show 'Tell the server that we are ready.'}
    Ready = unit
end



