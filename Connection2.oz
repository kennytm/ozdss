functor
import
    System
    Application
    Pickle
    Open
    DSSCommon
    ProxyValue

define
    %%% Store all tickets that can be taken. The key is the ticket ID, and the
    %%% values can be `once(X Y Z)`, meaning `X#Y#Z` should be sent to the other
    %%% side and be deleted after taken, or `many(X Y Z)`, for it won't be
    %%% deleted.
    %%%
    %%% The `X`, `Y` and `Z` are
    %%%  X. The value itself.
    %%%  Y. The list of names which will become ReflectiveVariable when sent to
    %%%     the other side.
    %%%  Z. The list of names which will become ReflectiveEntity when sent to
    %%%     the other side.
    TicketStore = {NewDictionary}
    NextTicketID = {NewCell 0}

    %%% Initialize the connection module.
    proc {Init}
        Server
    in
        {DSSCommon.init}

        % We don't care about the finalizer stream. We just want those variables
        % go away if no one need them.
        {WeakDictionary.close ProxyStore}

        {RunServer}
    end

    fun {SerializeResponse StatusCodeAndData}
        {Pickle.pack StatusCodeAndData}
    end

    fun {DeserializeResponse RawData}
        {Pickle.unpack RawData}
    end

    proc {DeserializeRequest RawData ?Action ?ReplyIP ?ReplyPort ?Data}
        Action(ReplyIP ReplyPort Data) = {Pickle.unpack RawData}
    end

    fun {SerializeRequest Action IP Port Data}
        {Pickle.pack Action(IP Port Data)}
    end

    fun {TakeSender TicketID IP Port}
        case {Dictionary.condGet TicketStore TicketID unit}
        of many(Info) then
            ok(Info)
        [] once(Info) then
            {Dictionary.remove TicketStore TicketID}
            ok(Info)
        else
            notFound
        end
    end

    fun {TakeReceiver StatusCodeAndData}
        case StatusCodeAndData
        of ok(Info) then

        [] Status then
            raise Status end
        end
    end

    Senders = r(
        take: TakeSender
    )

    Receivers = r(
        take: TakeReceiver
    )


    proc {RunServer}
        S = {New Open.socket init}
    in
        {S bind(takePort:{DSSCommon.getPort})}
        {S listen}
        thread
            for while:true do C in
                {S accept(acceptClass:Open.socket accepted:C)}
                thread
                    Data Action IP Port
                    StatusCodeAndData = try
                        {DeserializeRequest {C read(list:$)} ?Action ?IP ?Port ?Data}
                        {Senders.Action Data IP Port}
                    catch _ then
                        internalServerError
                    end
                in
                    {C send(vs:{SerializeResponse StatusCodeAndData})}
                end
            end
        end
        S
    end

    proc {RunClient Host Port Action Info}
        C = {New Open.socket init}
        Data
        Result
    in
        {C client(host:Host port:Port)}
        {C send(vs:{SerializeRequest Action {DSSCommon.myIP} {DSSCommon.myPort} Info})}
        Data = {C read(list:$)}
        Result = {Receivers.Action {DeserializeResponse Data}}
        {C shutDown(how:[receive])}
        Result
    end

    fun {ParseData Data}
        % Actually I prefer an HTTP-based protocol, but currently Oz doesn't
        % have a regex module.
        Action(ReplyIP ReplyPort Info) = {Pickle.unpack Data}
        {New RequestClasses.Action init(ReplyIP ReplyPort Info)}
    end

    fun {OfferOnce Data}
        TicketID = @NextTicketID
    in
        NextTicketID := TicketID + 1

    end
in
    {Init}
end

