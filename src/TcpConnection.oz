functor

import
    OS
    Pickle
    StdEx
    System
    UrlTools

export
    Connections

define

    %%% Base class of the DSS packet protocol, based on TCP connections.
    class Connections from BaseObject
        feat
            serverName
            port
            acceptor
            server

            % Dictionary of client name → client instance / address / port
            clientAddresses


        %%% Create a new connection pool.
        %%%
        %%% * `port`: the port number for listening to incoming connections
        %%% * `ipVersion`: the IP version (4 or 6) where external connections
        %%%                will be accepted.
        %%% * `server`: a Port instance to receive incoming packets.
        %%%
        meth init(port:PortNum ipVersion:IPVersion<=4 server:ServerPort)
            self.serverName = {NewName}
            self.port = PortNum
            self.acceptor = {OS.tcpAcceptorCreate IPVersion PortNum}
            self.server = ServerPort
            self.clientAddresses = {NewDictionary}
            thread
                {self '_listen'}
            end
        end

        meth '_listen'
            PackedServerName = {Pickle.pack self.serverName} in
            for do Client in
                Client = {OS.tcpAccept self.acceptor}
                {self '_addClient'(Client clientName:_)}
            end
        end

        meth '_sendPacket'(client:Client content:VBS status:?Status)
            LengthBS = {StdEx.toLittleEndianBytes {VirtualByteString.length VBS} 4} in
            Status = {OS.tcpConnectionWrite Client LengthBS#VBS}
        end

        meth readPacket(client:Client content:?Content)
            LengthBS = {OS.tcpConnectionRead Client 4 $ nil ?_}
            Length = {StdEx.fromLittleEndianBytes LengthBS} in
            {OS.tcpConnectionRead Client Length ?Content nil ?_}
        end

        meth '_serve'(Client clientName:?N)
            ClientNameCell = {NewCell unit}
            ClientPortCell = {NewCell 0} in
            for do
                Tag1|Tag2|Content = {self readPacket(client:Client content:$)} in
                case [Tag1 Tag2]
                of "nm" then
                    ClientHost#ClientPort#ClientName = {Pickle.unpack Content} in
                    ClientNameCell := ClientName
                    ClientPortCell := ClientPort
                    {Dictionary.put self.clientAddresses ClientName Client#ClientHost#ClientPort}
                    if {IsFree N} then
                        N = ClientName
                    end
                [] Tag then
                    {Send self.server @ClientNameCell#Tag#Content}
                end
            end
        end

        meth '_addClient'(Client clientName:?N)
            thread
                {self '_serve'(Client clientName:?N)}
            end
            {self '_sendHello'(Client status:_)}
        end

        meth '_sendHello'(Client status:?Status)
            HelloPacket = "nm"#{Pickle.pack {UrlTools.getLocalAddress}#self.port#self.serverName} in
            {self '_sendPacket'(client:Client content:HelloPacket status:?Status)}
        end

        %%% Creates a new connection.
        meth connect(host:Host port:PortNum clientName:?N) Client in
            Client = {OS.tcpConnect Host PortNum}
            {self '_addClient'(Client clientName:?N)}
        end

        meth send(clientName:N tag:Tag content:Content status:?Status)
            Client#ClientHost#ClientPort = {Dictionary.get self.clientAddresses N} in
            % if the client is closed we should reconnect using ClientHost#ClientPort.
            {self '_sendPacket'(client:Client content:Tag#Content)}
        end
    end

end
