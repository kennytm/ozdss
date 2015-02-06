functor

import
    TcpConnection
    Pickle

export
    dssServer: DSSServer

define

    %%% Server for DSS
    class DSSServer
        feat
            connections
            clientStatus % ClientName -> Status
            faultStreams % ObjectName -> Stream
            sharedObjects % ObjectName -> owned objects shared to downlinks
            ticketStore % TicketID -> SerializedObject
            ticketQueues % ClientName#TicketID -> _
            downlinks % ObjectName -> [ClientName]
            uplinks % ObjectName -> [ClientName]
            rtts % ClientName -> (round trip time)#(heartbeat send time)
            pingThreads % ClientName -> Thread

        attr
            nextTicketId

        meth init(port:PortNum ipVersion:IPVersion<=4)
            Stream
            Port = {NewPort ?Stream} in
            self.connections = {New TcpConnection.connections init(
                port: PortNum
                ipVersion: IPVersion
                server: Port
            )}
            self.clientStatus = {NewDictionary}
            self.faultStreams = {NewDictionary}
            self.ticketStore = {NewDictionary}
            self.ticketQueues = {NewDictionary}
            self.downlinks = {NewDictionary}
            self.uplinks = {NewDictionary}
            self.sharedObjects = {NewDictionary}
            self.rtts = {NewDictionary}
            self.pingThreads = {NewDictionary}
            nextTicketId := 1

            thread
                for ClientName#Tag#Content in Stream do
                    {self '_setClientStatus'(ClientName ok)}
                    {self '_handlePacket'(ClientName Tag Content)}
                end
            end
        end

        meth '_setClientStatus'(ClientName Status)
            OldStatus in
            {Dictionary.condExchange ClientName Status OldStatus Status}
            if OldStatus \= Status then
                for Key#Stream in {Dictionary.entries self.faultStreams} do
                    NewStream in
                    Stream = Status|NewStream
                    {Dictionary.put Key NewStream}
                end
            end
        end

        meth '_pickleAndLink'(Obj downlink:ClientName ?Result)
            %%% reuse the implementation from ozdss4 or ozdss3 here.
            % SharedObjectNames
            % Serialized = {Pickle.packWithReplaceAllObjectsAsChunks Obj ?SharedObjectNames} in
            % for Object#Name in SharedObjectNames do
            %     {self '_downlink'(object:Name client:ClientName)}
            %     {Dictionary.put self.sharedObjects Name Object}
            %     % ^ keep the object from being GC'ed until all downlinks are disconnected.
            % end
            % Result = Serialized
            skip
        end

        meth '_unpickleWithLink'(Bytes uplink:ClientName ?Result)
            %%% reuse the implementation from ozdss4 or ozdss3 here.
            % ReflectiveObjectNames
            % Object = {Pickle.unpackAndReplaceAllChunksAsReflectiveObjects Bytes ?ReflectiveObjectNames} in
            % for Object#Name in ReflectiveObjectNames do
            %     {self '_uplink'(object:Name client:ClientName}
            %     % set up a post-mortem for Object, which sends a GC message using Name
            %     % something like:
            %     {Finalize.postMortem Object Name proc {$ N}
            %         for Client in {Dictionary.condGet self.uplinks N nil} do
            %             {self.connections send(clientName:Client tag:"gc" content:{Pickle.pack N} status:_)}
            %         end
            %     end}
            % end
            % Result = Object
            skip
        end

        meth '_downlink'(object:N client:CN)
            %%% We need a `std::unordered_multimap` or in-memory sqlite3!
            %%% Convert this to condExchange or something.
            G = {Dictionary.condGet self.downlinks N unit} in
            case G
            of unit then
                {Dictionary.put self.downlinks N [CN]}
            [] T then
                {Dictionary.put self.downlinks N /*makeUnique:*/CN|T}
            end
        end

        meth '_uplink'(object:N client:CN)
            %%% We need a `std::unordered_multimap` or in-memory sqlite3!
            %%% Convert this to condExchange or something.
            G = {Dictionary.condGet self.uplinks N unit} in
            case G
            of unit then
                {Dictionary.put self.uplinks N [CN]}
            [] T then
                {Dictionary.put self.uplinks N /*makeUnique:*/CN|T}
            end
        end

        meth '_removeObjectLink'(N downlink:CN)
            DownlinkClients = {Dictionary.get self.downlinks N}
            NewClients = {List.subtract DownlinkClients CN} in
            if NewClients \= nil then
                {Dictionary.put self.downlinks N NewClients}
            else
                {Dictionary.remove self.downlinks N}
                {Dictionary.remove self.sharedObjects N}
                {Dictionary.condGet self.faultStreams N _} = nil
                {Dictionary.remove self.faultStreams N}
            end
        end

        meth '_kill'(N)
            Downlinks = {Dictionary.condGet self.downlinks N nil}
            Uplinks = {Dictionary.condGet self.uplinks N nil} in
            {Dictionary.remove self.downlinks N}
            {Dictionary.remove self.uplinks N}
            {Dictionary.condGet self.faultStreams N _} = permFail|_
            {Dictionary.remove self.faultStreams N}
            {Dictionary.remove self.sharedObjects N}
            for CN in Downlinks do
                {self.connections send(clientName:CN tag:"ki" contents:N status:_)}
            end
            for CN in Uplinks do
                {self.connections send(clientName:CN tag:"ki" contents:N status:_)}
            end
        end

        meth '_handlePacket'(ClientName Tag Content)
            % If we Alice take X from Bob, then:
            % Bob (the owner) will associate a downlink from X to Alice.
            % Alice (the taker) will associate an uplink from X to Bob.

            case Tag
            of "tk" then
                TicketID = {Pickle.unpack Content}
                Content = case {Dictionary.condGet TicketID unit}
                    of unit then {Value.error nooffer}
                    [] S then S
                end
                Serialized = {self '_pickleAndLink'(TicketID#Content downlink:ClientName $)} in
                {self.connections send(clientName:ClientName tag:"of" content:Content)}
            [] "of" then
                TicketID#Object = {self '_unpickleWithLink'(Content uplink:ClientName $)} in
                case {Dictionary.condGet self.ticketQueues ClientName#TicketID unit}
                    of unit then skip
                    [] F then F = Object
                end
            [] "gc" then
                ObjectName = {Pickle.unpack Content} in
                {self '_removeObjectLink'(ObjectName)}
            [] "ac" then
                ObjectName#Action = {self '_unpickleWithLink'(Content uplink:ClientName $)} in
                case {Dictionary.condGet self.sharedObjects ObjectName unit}
                    of unit then skip
                    [] Object then case {Label Action}
                        of 'send' then
                            {Send Object Action.1}
                        % and so on
                        else skip
                    end
                end
            [] "pn" then
                % TODO deal with consecutive pings.
                {self.connections send(clientName:ClientName tag:"hb" content:Content)}
                thread
                    {Dictionary.put self.pingThreads ClientName {Thread.this}}
                    % TODO use RTT
                    {Delay 100}
                    {self '_setClientStatus'(ClientName tempFail)}
                end
            [] "hb" then
                % TODO update RTT
                {Thread.cancel {Dictionary.get self.pingThreads ClientName}}
            [] "ki" then
                ObjectName = {Pickle.unpack Content} in
                {self '_kill'(ObjectName)}
            else
                skip
            end
        end

        meth offer(Object ticketId:?TicketId)
            TicketId = @nextTicketId
            {Dictionary.put self.ticketStore TicketId Object}
            nextTicketId := TicketId + 1
        end

        meth retract(ticketId:TicketId)
            {Dictionary.remove self.ticketStore TicketId}
        end

        meth take(client:ClientName ticketId:TicketId ?Result)
            SerializedTicketId = {Pickle.pack TicketId} in
            {Dictionary.put self.ticketQueues ClientName#TicketId Result}
            {self.connections send(
                clientName: ClientName
                tag: "tk"
                content: SerializedTicketId
                status: _    % TODO analyze the status as well.
            )}
        end

        meth '_findObjectName'(Object ?ObjectName)
            % [ObjectName] = [N suchthat N#O in {Dictionary.entries self.sharedObjects} if O == Object]
            for break:B N#O in {Dictionary.entries self.sharedObjects} do
                if O == Object then
                    ObjectName = N
                    {B}
                end
            end
        end

        meth getFaultStream(Object ?Result)
            Result = !!{Dictionary.get self.faultStreams {self '_findObjectName'(Object $)}}
        end

        meth kill(Object)
            {self '_kill'({self '_findObjectName'(Object $)})}
        end

        meth break(Object)
            N = {self '_findObjectName'(Object $)} in
            {Dictionary.remove self.downlinks N}
            {Dictionary.remove self.uplinks N}
            {Dictionary.condGet self.faultStreams N _} = localFail|_
            {Dictionary.remove self.faultStreams N}
            {Dictionary.remove self.sharedObjects N}
        end
    end


end

