functor
import
    System
    Pickle
    Open
    DSSCommon
    ProxyValue

export
    OfferOnce
    offer: OfferOnce
    OfferMany
    offerUnlimited: OfferMany
    Take

define
    %%% Store all tickets that can be taken. The key is the ticket ID, and the
    %%% values can be `once(X Y)`, meaning `X#Y` should be sent to the other
    %%% side and be deleted after taken, or `many(X Y)`, for it won't be deleted.
    %%%
    %%% The `X` and `Y` are
    %%%  X. The value itself.
    %%%  Y. The list of names which will become ReflectiveVariable/Entity when
    %%%     sent to the other side.
    TicketStore = {NewDictionary}
    NextTicketID = {NewCell 0}
    Initialized = {NewCell false}

    %%% Initialize the connection module.
    proc {Init}
        if {Not @Initialized} then
            {RunServer}
            Initialized := true
        end
    end

    % {{{ Low-level Serialization/Deserialization.

    %%% Serialize a status code and the containing data of the form `ok(...)`
    %%% or `notFound` etc. to in a VBS suitable for sending. This is mainly for
    %%% sending a reply from server to client.
    fun {SerializeResponse StatusCodeAndData}
        {Pickle.pack StatusCodeAndData}
    end

    %%% Deserialize a VBS into a status code and containg data of the form
    %%% `ok(...)` or `notFound` etc. This is mainly for receiving a reply from
    %%% server to client.
    fun {DeserializeResponse RawData}
        {Pickle.unpack RawData}
    end

    %%% Deserialize a VBS into a request. This is mainly for receiving a request
    %%% from client to server.
    proc {DeserializeRequest RawData ?Action ?ReplyIP ?ReplyPort ?Data}
        ReplyIPVS
    in
        post(Action ReplyIPVS ReplyPort Data) = {Pickle.unpack RawData}
        ReplyIP = {VirtualString.toCompactString ReplyIPVS}
    end

    %%% Serialize a request into VBS. This is mainly for sending a request from
    %%% client to server.
    fun {SerializeRequest Action IP Port Data}
        {Pickle.pack post(Action IP Port Data)}
    end

    % }}}

    % {{{ ProxyValue-related.

    %%% Create a callback function for the reflective entities. When the
    %%% callback function runs, a `perform` action will be sent to the client at
    %%% the corresponding IP:Port.
    proc {ProxyCallback IP#Port EncodedAction ProxyNames}
        for _#Name in ProxyNames do
            {ProxyValue.register Name IP#Port ProxyCallback}
        end
        {RunClient IP Port perform EncodedAction#ProxyNames}
    end

    proc {RegisterRemoteProxies IP Port ProxyNames}
        for Type#N in ProxyNames do
            {ProxyValue.addRemoteProxy Type N IP#Port ProxyCallback}
        end
    end

    proc {RegisterLocalProxies IP Port ProxyNames}
        for _#N in ProxyNames do
            {System.show [1 N IP Port]}
            {ProxyValue.register N IP#Port ProxyCallback}
            {System.show [2 N IP Port]}
        end
    end

    % }}}

    % {{{ Processors

    %%% An interface for all action precessors.
    class Processor from BaseObject
        meth reply(Info ip:IP port:Port result:?ReplyStatusCodeAndData)
            ReplyStatusCodeAndData = badRequest
        end

        meth onReply(IP Port StatusCodeAndData ?Reply)
            if {Label StatusCodeAndData} \= ok then
                {Exception.raiseError StatusCodeAndData}
            else
                Message = receive(ip:IP port:Port result:?Reply)
            in
                {self {Adjoin StatusCodeAndData Message}}
            end
        end
    end

    class TakeProcessor from Processor
        meth reply(TicketID ip:IP port:Port result:?Result)
            case {Dictionary.condGet TicketStore TicketID unit}
            of t(Persistence Value ProxyNames) then
                % Found a ticket. We register those proxies to the client's IP
                % and port, so they could transparently receive the updates.
                {System.show ProxyNames}
                {RegisterLocalProxies IP Port ProxyNames}

                % Remove the ticket if it can only be offered once.
                if Persistence == once then
                    {Dictionary.remove TicketStore TicketID}
                end

                Result = ok(Value ProxyNames)
            else
                % Ticket not found.
                Result = notFound
            end
        end

        meth receive(Value ProxyNames ip:IP port:Port result:?Result)
            {RegisterRemoteProxies IP Port ProxyNames}
            Result = {ProxyValue.decode Value}
        end
    end

    class PerformProcessor from Processor
        meth reply(Info ip:IP port:Port result:?Result)
            Action#ProxyNames = Info
        in
            {RegisterRemoteProxies IP Port ProxyNames}
            {ProxyValue.injectAction Action IP#Port}
            Result = ok
        end

        meth receive(...)
            skip
        end
    end

    Processors = r(
        take: {New TakeProcessor noop}
        perform: {New PerformProcessor noop}
    )

    %}}}

    % {{{ Server/client

    ServerBlockingQueue = {NewCell nil}

    proc {RunServer}
        S = {New Open.socket init}
    in
        {S bind(takePort:{DSSCommon.myPort})}
        {S listen}
        thread
            for do
                C = {S accept(acceptClass:Open.socket accepted:$)}
            in
                thread
                    RawData Data Action IP Port StatusCodeAndData
                in
                    % Block until the server is free to read anything.
                    {ForAll {Exchange ServerBlockingQueue $ nil} Wait}
                    StatusCodeAndData = try
                        Data = {DeserializeRequest {C read(list:$)} ?Action ?IP ?Port}
                        {System.show [Action IP Port Data]}
                        {Processors.Action reply(Data ip:IP port:Port result:$)}
                    catch E then
                        {System.show E}
                        internalServerError
                    end
                    {System.show StatusCodeAndData}
                    {C write(vs:{SerializeResponse StatusCodeAndData})}
                end
            end
        end
    end

    fun {WithBlockingServer F}
        OldValue
        Blocker
        RetVal
    in
        {Exchange ServerBlockingQueue OldValue (!!Blocker)|OldValue}
        RetVal = {F}
        Blocker = unit % unblock the server by making it deterministic.
        RetVal
    end

    fun {RunClient IP Port Action Info}
        C = {New Open.socket client(host:IP port:Port)}
        Result
    in
        % Block the server until we have atomically sent and received the data
        % we need. This avoids race condition when the server gives us something
        % we aren't ready to digest.
        Result = {WithBlockingServer fun {$}
            Data
        in
            {System.show 'sending...'}
            {C send(vs:{SerializeRequest Action {DSSCommon.myIP} {DSSCommon.myPort} Info})}
            {System.show 'reading...'}
            Data = {C read(list:$)}
            {System.show 'replying...'}
            {Processors.Action onReply(IP Port {DeserializeResponse Data} $)}
        end}
        {C close}
        Result
    end

    % }}}

    fun {OfferWithPeristence Persistence V}
        TicketID
        NewTicketID
        EncocdedData
        NewProxyNames = {NewCell nil}
    in
        {Init}

        % Atomically increase the ticket ID.
        {Exchange NextTicketID ?TicketID ?NewTicketID}
        NewTicketID = TicketID + 1

        EncocdedData = {ProxyValue.encode V ?NewProxyNames}
        {Dictionary.put TicketStore TicketID t(Persistence EncocdedData @NewProxyNames)}

        {DSSCommon.getTicketPrefix}#TicketID
    end

    fun {OfferOnce V}
        {OfferWithPeristence once V}
    end

    fun {OfferMany V}
        {OfferWithPeristence many V}
    end

    fun {Take TicketURL}
        IP Port TicketID
    in
        {Init}
        {DSSCommon.parseTicketURL TicketURL ?IP ?Port ?TicketID}
        {RunClient IP Port take TicketID}
    end
end

