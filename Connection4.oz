functor
import
    Connection2
    System
    Property
    DSSCommon

define
    {DSSCommon.setPort 9001}

    {System.show {DSSCommon.myPort}}

    OMG = {Connection2.take 'oz-ticket://192.168.100.211:9000/tickets/90a1901d-a424-4441-89d7-f075d70fd2c0/0'}

    {System.show OMG}

    OMG.1 = 12356
    {Assign OMG.3 3456}

    {System.show OMG}

    {Time.delay 3000}

    {System.show [preparing to show]}

    {System.show @(OMG.3)}


end



