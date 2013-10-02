functor
import
    System
    Pickle
    Open
    DSSCommon
    ReflectionEx

export
    OfferOnce
    offer: OfferOnce
    OfferMany
    offerUnlimited: OfferMany
    Take

define
    %%% Store all tickets that can be taken. The key is the ticket ID, and the
    %%% values can be `once#X#Y#Z`, meaning `X#Y#Z` should be sent to the other
    %%% side and be deleted after taken, or `many#X#Y#Z`, for it won't be
    %%% deleted.
    %%%
    %%% The `X`, `Y` and `Z` are
    %%%  X. The value itself.
    %%%  Y. The list of names which will become ReflectiveVariable when sent to
    %%%     the other side.
    %%%  Z. Similar to Y, but is for ReflectiveEntity.
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

    DebugSerialization = true

    % {{{ Low-level Serialization/Deserialization.

    %%% Serialize a status code and the containing data of the form `ok(...)`
    %%% or `notFound` etc. to in a VBS suitable for sending. This is mainly for
    %%% sending a reply from server to client.
    fun {SerializeResponse StatusCodeAndData}
        if DebugSerialization then
            {System.show [server send {Thread.this} StatusCodeAndData]}
        end
        {Pickle.pack StatusCodeAndData}
    end

    %%% Deserialize a VBS into a status code and containg data of the form
    %%% `ok(...)` or `notFound` etc. This is mainly for receiving a reply from
    %%% server to client.
    fun {DeserializeResponse RawData}
        Result = {Pickle.unpack RawData}
    in
        if DebugSerialization then
            {System.show [client recv {Thread.this} Result]}
        end
        Result
    end

    %%% Deserialize a VBS into a request. This is mainly for receiving a request
    %%% from client to server.
    %%%
    %%% Returns whether the site ID of the request matches this site's real ID.
    fun {DeserializeRequest RawData ?Action ?ReplyIP ?ReplyPort ?ReplySiteID ?Data}
        SiteID
    in
        post(SiteID Action ReplyIP ReplyPort ReplySiteID Data) = {Pickle.unpack RawData}
        if DebugSerialization then
            {System.show [server recv {Thread.this} Action Data]}
        end
        SiteID == {DSSCommon.mySiteID}
    end

    %%% Serialize a request into VBS. This is mainly for sending a request from
    %%% client to server.
    fun {SerializeRequest SiteID Action ReplyIP ReplyPort ReplySiteID Data}
        if DebugSerialization then
            {System.show [client send {Thread.this} Action Data]}
        end
        {Pickle.pack post(SiteID Action ReplyIP ReplyPort ReplySiteID Data)}
    end

    % }}}

    % {{{ Reflection related.

    %%% Create a callback function for the reflective entities. When the
    %%% callback function runs, a `perform` action will be sent to the client at
    %%% the corresponding IP:Port.
    proc {ReflectionCallback SiteID IP#Port SrcName EncodedAction VarNames TokenNames}
        _ = {RunClient IP Port SiteID perform EncodedAction#VarNames#TokenNames#SrcName}
    end

    % }}}

    % {{{ Processors

    %%% An interface for all action precessors.
    class Processor from BaseObject
        %%% Reply a message received from the client.
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

        %%% Receive a message from the server
        % meth receive(... ip:IP port:Port siteID:SiteID result:?Reply)
        %     skip
        % end
    end

    class TakeProcessor from Processor
        meth reply(TicketID ip:IP port:Port siteID:SiteID result:?Result)
            case {Dictionary.condGet TicketStore TicketID unit}
            of Persistence#Value#VarNames#TokenNames then
                % Found a ticket. We register those proxies to the client's IP
                % and port, so they could transparently receive the updates.
                {ReflectionEx.registerRemoteObjects variable VarNames SiteID ReflectionCallback IP#Port}
                {ForAll TokenNames ReflectionEx.tokenAddRef}

                % Remove the ticket if it can only be offered once.
                if Persistence == once then
                    {Dictionary.remove TicketStore TicketID}
                end

                Result = ok(Value#VarNames#TokenNames)
            else
                % Ticket not found.
                Result = notFound
            end
        end

        meth receive(Info ip:IP port:Port siteID:SiteID result:?Result)
            Value#VarNames#TokenNames = Info
        in
            {ReflectionEx.registerRemoteObjects variable VarNames SiteID ReflectionCallback IP#Port}
            {ReflectionEx.registerRemoteObjects token TokenNames SiteID ReflectionCallback IP#Port}
            Result = {ReflectionEx.decode Value}
        end
    end

    class PerformProcessor from Processor
        meth reply(Info ip:IP port:Port siteID:SiteID result:?Result)
            Action#VarNames#TokenNames#SrcName = Info
        in
            {ReflectionEx.registerRemoteObjects variable VarNames SiteID ReflectionCallback IP#Port}
            {ReflectionEx.registerRemoteObjects token TokenNames SiteID ReflectionCallback IP#Port}
            {ReflectionEx.performAction SrcName {ReflectionEx.decode Action} SiteID}
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

    %%% Read a list of bytes from S, written using WriteSocket.
    fun {ReadSocket S}
        [R0 R1 R2 R3] = {S read(list:$ size:4)}
        Size = R0 + 256*(R1 + 256*(R2 + 256*R3))
    in
        {S read(list:$ size:Size)}
    end

    %%% Write a virtual byte string VBS into the socket S, prefixed by the
    %%% length of VBS.
    proc {WriteSocket S VBS}
        L0 = {VirtualByteString.length VBS}
        R0 = L0 mod 256
        L1 = L0 div 256
        R1 = L1 mod 256
        L2 = L1 div 256
        R2 = L2 mod 256
        L3 = L2 div 256
        R3 = L3 mod 256
    in
        {S write(vs:[R0 R1 R2 R3])}
        {S write(vs:VBS)}
    end

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
                    Data Action IP Port SiteID StatusCodeAndData
                in
                    % Block until the server is free to read anything.
                    {ForAll {Exchange ServerBlockingQueue $ nil} Wait}
                    StatusCodeAndData = try
                        if {DeserializeRequest {ReadSocket C} ?Action ?IP ?Port ?SiteID ?Data} then
                            {Processors.Action reply(Data ip:IP port:Port siteID:SiteID result:$)}
                        else
                            badRequest
                        end
                    catch E then
                        {System.show E}
                        internalServerError
                    end
                    {WriteSocket C {SerializeResponse StatusCodeAndData}}
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
            VS
        in
            VS = {SerializeRequest SiteID Action
                                   {DSSCommon.myIP} {DSSCommon.myPort}
                                   {DSSCommon.mySiteID}
                                   Info}
            {WriteSocket C VS}
            Data = {DeserializeResponse {ReadSocket C}}
            {Processors.Action onReply(IP Port SiteID Data $)}
        end}
        {C close}
        Result
    end

    % }}}

    fun {OfferWithPeristence Persistence V}
        TicketID
        NewTicketID
        EncocdedData VarNames TokenNames
    in
        {Init}

        % Atomically increase the ticket ID.
        {Exchange NextTicketID ?TicketID ?NewTicketID}
        NewTicketID = TicketID + 1

        EncocdedData = {ReflectionEx.encode V ?VarNames ?TokenNames}
        {Dictionary.put TicketStore TicketID Persistence#EncocdedData#VarNames#TokenNames}

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
    in
        {Init}
        {DSSCommon.parseTicketURL TicketURL ?IP ?Port ?SiteID ?TicketID}
        {RunClient IP Port SiteID take TicketID}
    end
end

