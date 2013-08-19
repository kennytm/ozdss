functor
import
    Connection2
    System
    Property
    DSSCommon

define
    {DSSCommon.setPort 9001}

    {System.show {DSSCommon.myPort}}

    OMG = {Connection2.take 'oz-ticket://192.168.100.211:9000/tickets/' #
        'c85bd1db-6482-4fc3-b0e9-99e5a28e147b/0'}

    {System.show OMG}

    {Assign OMG 3456}

    {System.show OMG}

    {Time.delay 3000}

    {System.show [preparing to show]}

    {System.show {Access OMG}}


end



