functor
import
    Reflection at 'x-oz://boot/Reflection'
    LinearDictionary
    GenericDictionary
    System
    Pickle

export
    Encode
    Decode
    Register
    AddRemoteProxy
    InjectAction

define
    %%% Store all variables & entities which has been sent elsewhere. The keys
    %%% should be names and the values are proxies. Once a variable becomes
    %%% bound via a reflective bind, the corresponding entry should be dropped.
    ProxyStore = {NewWeakDictionary ?_}

    %%% Just a dummy value to indicate a defaulted parameter.
    Missing = {NewName}

    fun {HRN N}
        B = {VirtualByteString.toCompactByteString {Pickle.pack N}}
    in
        {CompactByteString.slice B 13 {CompactByteString.length B}}
    end

    %%% A placeholder which will holds the bridge between a reflective
    %%% variable/entity and the represented object. This class must be private.
    class Proxy
        feat
            name
            value
            reflObject
            isLocal

        attr
            callbacks: {GenericDictionary.new Value.'<'}

        meth init(Type value:Value<=unit name:Name<={NewName})
            Stream
        in
            self.name = Name
            if Type == variable then
                self.reflObject = {Reflection.newReflectiveVariable ?Stream}
                self.isLocal = {IsFree Value}
                if self.isLocal then
                    Value = self.reflObject
                end
            else
                self.reflObject = {Reflection.newReflectiveEntity ?Stream}
                self.isLocal = (Value \= unit)
                self.value = if self.isLocal then
                    {Reflection.becomeExchange Value self.reflObject}
                else
                    unit
                end
            end

            {System.show [{HRN self.name} init(Type) self.isLocal]}

            thread
                {self processStream(Stream)}
            end
        end

        meth processStream(Stream)
            Action#Confirmation = Stream.1
        in
            {self injectAction(Action)}
            Confirmation = unit
            {self processStream(Stream.2)}
        end

        meth invokeCallbacks(Action ExcludeCallbackKey)
            % Encode the action into sendable form.
            NewProxyNamesCL = {NewCell nil}
            DataToSend
            NewProxyNames
        in
            DataToSend = {Encode Action NewProxyNamesCL}
            NewProxyNames = @NewProxyNamesCL
            % Send this action to other people.
            {GenericDictionary.forAllInd @callbacks proc {$ K Callback#Context}
                if K \= ExcludeCallbackKey then
                    thread
                        {Callback K Context self.name DataToSend NewProxyNames}
                    end
                end
            end}
        end

        meth injectAction(Action ExcludeCallbackKey<=Missing)
            {System.show [{HRN self.name} Action self.isLocal]}
            case Action
            of bind(X) then
                % Bind is special. We can only bind once. The rest is out of our
                % control. So just remove ourselves from the global dictionary.
                {Reflection.bindReflectiveVariable self.reflObject X}
                {WeakDictionary.remove ProxyStore self.name}

                % We also need to tell the other sites that a value is bound,
                % regardless local or remote.
                {self invokeCallbacks(Action ExcludeCallbackKey)}
            else
                if self.isLocal then
                    {self performAction(Action ExcludeCallbackKey)}
                else
                    {self sendRemoteAction(Action ExcludeCallbackKey)}
                end
            end
        end

        meth performAction(Action ExcludeCallbackKey)
            % Run an action where we have a *known object* to operate on.
            case Action
            of assign(X) then {Assign self.value X}
            [] isCell(?R) then R = {IsCell self.value}
            [] access(?R) then R = {Access self.value}
            [] arrayGet(I ?R) then R = {Get self.value I}
            [] arrayPut(I V) then {Put self.value I V}
            [] arrayExchange(I ?O N) then {Array.exchange self.value I ?O N}
            [] isArray(?R) then R = {IsArray self.value}
            [] arrayHigh(?R) then R = {Array.high self.value}
            [] arrayLow(?R) then R = {Array.low self.value}
            else
                {System.show unknownAction(Action)}
                {Exception.raiseError unknownAction(Action)}
            end
        end

        meth sendRemoteAction(Action ExcludeCallbackKey)
            % Run an action where we don't have a known object to operation on.
            % What we can do is the reach for the server, and wait until they
            % give us the known value.
            {self invokeCallbacks(Action ExcludeCallbackKey)}
        end

        meth register(Key Callback Context)
            OldCallbacks NewCallbacks
        in
            OldCallbacks = callbacks <- NewCallbacks
            NewCallbacks = {GenericDictionary.put OldCallbacks Key Callback#Context}
        end

        meth unregister(Key)
            OldCallbacks NewCallbacks
        in
            OldCallbacks = callbacks <- NewCallbacks
            NewCallbacks = {GenericDictionary.remove OldCallbacks Key}
        end
    end

    fun {IsProxy V}
        {IsObject V} andthen {OoExtensions.getClass V} == Proxy
    end

    fun {AddProxy Type Value}
        P = {New Proxy init(Type value:Value)}
    in
        {WeakDictionary.put ProxyStore P.name P}
        P.name
    end

    fun {MapWalkImpl V OnVariable OnToken OnName References}
        case {Reflection.getStructuralBehavior V}
        of value then
            V
        [] variable then
            {OnVariable V}
        [] token then
            OldDict NewDict OldValue NewValue Transformer Existing
        in
            {Exchange References ?OldDict ?NewDict}
            NewDict = {LinearDictionary.condPut OldDict V ?OldValue NewValue ?Existing}
            if Existing then
                OldValue
            else
                Transformer = if {IsName V} then OnName else OnToken end
                NewValue = {Transformer V}
                NewValue
            end

        [] structural then
            % Ensure we don't visit the same structure/token recursively.
            OldDict NewDict OldRecord NewRecord Existing
        in
            {Exchange References OldDict NewDict}
            NewDict = {LinearDictionary.condPut OldDict V ?OldRecord NewRecord ?Existing}
            if Existing then
                OldRecord
            else
                NewLabel = {MapWalkImpl {Label V} OnVariable OnToken OnName References}
                NewContent = {Map {Record.toListInd V} fun {$ X#Y}
                    Key = {MapWalkImpl X OnVariable OnToken OnName References}
                    Value = {MapWalkImpl Y OnVariable OnToken OnName References}
                in
                    Key#Value
                end}
            in
                NewRecord = {List.toRecord NewLabel NewContent}
                NewRecord
            end
        end
    end

    %%% Walk recursively on the structure of V. Return a value mirroring the
    %%% structure of V, but with variables replaced by the return value of
    %%% function OnVariable and tokens by OnToken.
    fun {MapWalk V OnVariable OnToken OnName}
        {MapWalkImpl V OnVariable OnToken OnName {NewCell {LinearDictionary.new}}}
    end

    fun {Identity X}
        X
    end

    %%% Convert all variables and stateful values to Proxy's.
    fun {Encode V NewProxyNamesCL}
        proc {AppendToCL Type N}
            OldList
        in
            {Exchange NewProxyNamesCL OldList Type#N|OldList}
        end

        fun {HandleReflectiveObject Type Object Checker}
            if {Checker Object} then
                for return:R N#Proxy in {WeakDictionary.entries ProxyStore} do
                    if Proxy.reflObject == Object then
                        if {Not {Member Type#N @NewProxyNamesCL}} then
                            {AppendToCL Type N}
                        end
                        {R N}
                    end
                end
            else
                N = {AddProxy Type Object}
            in
                {AppendToCL Type N}
                N
            end
        end

        fun {OnVariable Var}
            {HandleReflectiveObject variable Var Reflection.isReflectiveVariable}
        end

        fun {OnToken Token}
            if {IsProxy Token} then
                Token.name
            else
                {HandleReflectiveObject token Token fun {$ T}
                    {Value.type T} == reflective
                end}
            end
        end
    in
        {MapWalk V OnVariable OnToken /*OnName=*/Identity}
    end

    fun {Decode V}
        fun {OnName N}
            Res = {WeakDictionary.condGet ProxyStore N unit}
        in
            if Res \= unit then
                Res.reflObject
            else
                N
            end
        end

        Res
    in
        {MapWalk V /*OnVariable=*/Identity /*OnToken=*/Identity OnName}
    end

    %%% Register a callback on a proxy represented by the name N. The callback
    %%% is called whenever an action is performed on the object.
    proc {Register N Key Callback Context}
        P = {WeakDictionary.condGet ProxyStore N unit}
    in
        if P \= unit then
            {P register(Key Callback Context)}
        end
    end

    %%% Add a proxy object which does not exist on the local site.
    proc {AddRemoteProxy Type Name Key ReplyCallback ReplyContext}
        P = {New Proxy init(Type name:Name)}
    in
        {P register(Key ReplyCallback ReplyContext)}
        {WeakDictionary.put ProxyStore Name P}
    end

    proc {InjectAction N Action ExcludeCallbackKey}
        P = {WeakDictionary.condGet ProxyStore N unit}
    in
        if P \= unit then
            {P injectAction(Action ExcludeCallbackKey)}
        end
    end
in
    % We don't care about the finalizer stream. We just want those variables
    % go away if no one need them.
    {WeakDictionary.close ProxyStore}
end

