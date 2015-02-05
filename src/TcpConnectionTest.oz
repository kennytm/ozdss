functor

import
    TcpConnection

export
    Return

define
    Return = tcpConnectionTests([
        a(proc {$}
            ServerStream
            ServerPort = {NewPort ?ServerStream}
            ClientStream
            ClientPort = {NewPort ?ClientStream}
            ServerName
            Server = {New TcpConnection.connections init(port:38018 server:ServerPort)}
            Client = {New TcpConnection.connections init(port:44817 server:ClientPort)}
        in
            {Client connect(host:localhost port:Server.port clientName:ServerName)}
        end)
    ])

end
