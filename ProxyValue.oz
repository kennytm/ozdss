functor
export
    Encode
    Decode

import
    Reflection at 'x-oz://boot/Reflection'
    IdentityDictionary

define
    %%% Store all variables & entities which has been sent elsewhere. The keys
    %%% should be names and the values are proxies. Once a variable becomes
    %%% bound via a reflective bind, the corresponding entry should be dropped.
    ProxyStore = {NewWeakDictionary ?_}

    %%% A placeholder which will holds the bridge between a reflective
    %%% variable/entity and the represented object. This class must be private.
    class Proxy
        feat
            name
            value
            reflObject
            callbacks: {NewDictionary}

        meth init(Type Value<=unit)
            Stream
        in
            self.name = {NewName}
            if Type == variable then
                self.reflObject = {Reflection.newReflectiveVariable ?Stream}
                if {IsFree Value} then
                    Value = self.reflObject
                end
            else
                self.reflObject = {Reflection.newReflectiveEntity ?Stream}
                if Value \= unit then
                    self.value = {Reflection.becomeExchange Value self.reflObject}
                end
            end

            thread
                {self processStream(Stream)}
            end
        end

        meth processStream(Stream)
            Action#Confirmation = Stream.1
            NewProxyNamesCL = {NewCell nil}
            NewProxyNames
        in
            DataToSend = {Encode Action NewProxyNamesCL}
            NewProxyNames = @NewProxyNamesCL
            for Callback in {Dictionary.items self.callbacks} do
                {Callback DataToSend NewProxyNames}
            end
            {self doAction(Action)}
            Confirmation = unit
            {self processStream(Stream.2)}
        end

        meth doAction(Action)
            case Action
            of bind(X) then
                {Reflection.bindReflectiveVariable self.reflObject X}
            end
        end

        meth register(Key Callback)
            {Dictionary.put self.callbacks Key Callback}
        end

        meth unregister(Key)
            {Dictionary.remove self.callbacks Key}
        end
    end

    fun {IsProxy V}
        {IsObject V} andthen {OoExtensions.getClass V} == Proxy
    end

    fun {AddProxy Type Value}
        P = {New Proxy init(Type Value)}
    in
        {WeakDictionary.put ProxyStore P.name P}
        P.name
    end

    fun {MapWalkImpl V OnVariable OnToken OnName References}
        case {Reflection.getStructuralBehavior V}
        of value then
            if {IsName V} then
                {OnName V}
            else
                V
            end
        [] variable then
            {OnVariable V}
        [] token then
            {References condPut(V OnToken $)}
        [] structural then
            % Ensure we don't visit the same structure/token recursively.
            {References condPut(V fun {$ K}
                NewLabel = {MapWalkImpl {Label K} OnVariable OnToken References}
                NewContent = {Map {Record.toListInd K} fun {$ X#Y}
                    Key = {MapWalkImpl X OnVariable OnToken References}
                    Value = {MapWalkImpl Y OnVariable OnToken References}
                in
                    Key#Value
                end}
            in
                {List.toRecord NewLabel NewContent}
            end $)}
        end
    end

    %%% Walk recursively on the structure of V. Return a value mirroring the
    %%% structure of V, but with variables replaced by the return value of
    %%% function OnVariable and tokens by OnToken. The value Structures should
    %%% be initialized to `{IdentityDictionary.new}`.
    fun {MapWalk V OnVariable OnToken}
        {MapWalkImpl V OnVariable OnToken {IdentityDictionary.new}}
    end

    fun {Identity X}
        X
    end

    %%% Convert all variables and stateful values to Placeholders.
    fun {Encode V NewProxyNamesCL}
        fun {OnVariable Var}
            N = {AddProxy variable Var}
        in
            NewProxyNamesCL := variable#N|@NewProxyNamesCL
            N
        end

        fun {OnToken Token}
            if {IsProxy Token} then
                Token.name
            else
                N = {AddProxy token Token}
            in
                NewProxyNamesCL := token#N|@NewProxyNamesCL
                N
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
    in
        {MapWalk V /*OnVariable=*/Identity /*OnToken=*/Identity OnName}
    end
end

