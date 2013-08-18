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
    %%%
    %%% Returns whether the site ID of the request matches this site's real ID.
    fun {DeserializeRequest RawData ?Action ?ReplyIP ?ReplyPort ?ReplySiteID ?Data}
        ReplyIPVS SiteID
    in
        post(SiteID Action ReplyIPVS ReplyPort ReplySiteID Data) = {Pickle.unpack RawData}
        ReplyIP = {VirtualString.toCompactString ReplyIPVS}
        SiteID == {DSSCommon.mySiteID}
    end

    %%% Serialize a request into VBS. This is mainly for sending a request from
    %%% client to server.
    fun {SerializeRequest SiteID Action ReplyIP ReplyPort ReplySiteID Data}
        {Pickle.pack post(SiteID Action ReplyIP ReplyPort ReplySiteID Data)}
    end

    % }}}

    % {{{ ProxyValue-related.

    %%% Create a callback function for the reflective entities. When the
    %%% callback function runs, a `perform` action will be sent to the client at
    %%% the corresponding IP:Port.
    proc {ProxyCallback SiteID IP#Port SrcName EncodedAction ProxyNames}
        for _#Name in ProxyNames do
            {ProxyValue.register Name SiteID ProxyCallback IP#Port}
        end
        _ = {RunClient IP Port SiteID perform EncodedAction#ProxyNames#SrcName}
    end

    proc {RegisterRemoteProxies IP Port SiteID ProxyNames}
        for Type#N in ProxyNames do
            {ProxyValue.addRemoteProxy Type N SiteID ProxyCallback IP#Port}
        end
    end

    proc {RegisterLocalProxies IP Port SiteID ProxyNames}
        for _#N in ProxyNames do
            {ProxyValue.register N SiteID ProxyCallback IP#Port}
        end
    end

    % }}}

    % {{{ Processors

    %%% An interface for all action precessors.
    class Processor from BaseObject
        meth reply(Info ip:IP port:Port siteID:SiteID result:?ReplyStatusCodeAndData)
            ReplyStatusCodeAndData = badRequest
        end

        meth onReply(IP Port SiteID StatusCodeAndData ?Reply)
            if {Label StatusCodeAndData} \= ok then
                {Exception.raiseError StatusCodeAndData}
            else
                Message = receive(ip:IP port:Port siteID:SiteID result:?Reply)
            in
                {self {Adjoin StatusCodeAndData Message}}
            end
        end
    end

    class TakeProcessor from Processor
        meth reply(TicketID ip:IP port:Port siteID:SiteID result:?Result)
            case {Dictionary.condGet TicketStore TicketID unit}
            of t(Persistence Value ProxyNames) then
                % Found a ticket. We register those proxies to the client's IP
                % and port, so they could transparently receive the updates.
                {RegisterLocalProxies IP Port SiteID ProxyNames}

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

        meth receive(Value ProxyNames ip:IP port:Port siteID:SiteID result:?Result)
            {RegisterRemoteProxies IP Port SiteID ProxyNames}
            Result = {ProxyValue.decode Value}
        end
    end

    class PerformProcessor from Processor
        meth reply(Info ip:IP port:Port siteID:SiteID result:?Result)
            Action#ProxyNames#SrcName = Info
        in
            {RegisterRemoteProxies IP Port SiteID ProxyNames}
            {ProxyValue.injectAction SrcName {ProxyValue.decode Action} SiteID}
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
                    RawData Data Action IP Port SiteID StatusCodeAndData
                in
                    % Block until the server is free to read anything.
                    {ForAll {Exchange ServerBlockingQueue $ nil} Wait}
                    StatusCodeAndData = try
                        if {DeserializeRequest {C read(list:$)} ?Action ?IP ?Port ?SiteID ?Data} then
                            {Processors.Action reply(Data ip:IP port:Port siteID:SiteID result:$)}
                        else
                            badRequest
                        end
                    catch E then
                        {System.show E}
                        internalServerError
                    end
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

    fun {RunClient IP Port SiteID Action Info}
        C = {New Open.socket client(host:IP port:Port)}
        Result
    in
        % Block the server until we have atomically sent and received the data
        % we need. This avoids race condition when the server gives us something
        % we aren't ready to digest.
        Result = {WithBlockingServer fun {$}
            Data
            Res
        in
            {C send(vs:{SerializeRequest SiteID Action
                                         {DSSCommon.myIP} {DSSCommon.myPort}
                                         {DSSCommon.mySiteID}
                                         Info})}
            Data = {C read(list:$)}
            {Processors.Action onReply(IP Port SiteID {DeserializeResponse Data} $)}
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
        IP Port SiteID TicketID
        Result
    in
        {Init}
        {DSSCommon.parseTicketURL TicketURL ?IP ?Port ?SiteID ?TicketID}
        {RunClient IP Port SiteID take TicketID}
    end
end

