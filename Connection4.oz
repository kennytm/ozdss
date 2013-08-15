functor
import
    Connection2
    System
    Property
    DSSCommon

define
    {DSSCommon.setPort 9001}

    {System.show {DSSCommon.myPort}}

    OMG = {Connection2.take 'oz-ticket://127.0.0.1:9000/tickets/c7efaa8e-0d51-440c-9d39-955aae797453/0'}

    OMG.1 = 12356
    {Assign OMG.3 OMG}

    {System.show OMG}

end



