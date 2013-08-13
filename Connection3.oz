functor
import
    System
    Application
    Reflection at 'x-oz://boot/Reflection'
    Pickle
    Open
    DSSCommon

define
    Client1 = {New Open.socket client(host:'127.0.0.1' port:9000)}
    Client2 = {New Open.socket client(host:'127.0.0.1' port:9000)}

    {Client1 write(vs:'XDDD')}
    {Client2 write(vs:'WTF')}
    {System.show {Client1 read(list:$)}}
    {System.show {Client2 read(list:$)}}

    {Client1 close}
    {Client2 close}
end


