functor
import
    Reflection at 'x-oz://boot/Reflection'
    LinearDictionary
    ListEx
    System

export
    encode: P_Encode
    decode: P_Decode
    registerRemoteObjects: P_RegisterRemoteObjects
    tokenAddRef: P_TokenAddRef
    performAction: P_PerformAction

define
    %%% A class used to walk on something. This is mainly used for encoding and
    %%% decoding an object with serialization.
    % TODO Maybe we should modify the serializer directly.
    class C_Walker
        %{{{
        feat
            onName
            onToken
            onVariable
        attr
            referencesLD: {LinearDictionary.new}

        %%% Initialize the walker with some callbacks.
        meth init(onName:OnName<=P_Identity
                  onToken:OnToken<=P_Identity
                  onVariable:OnVariable<=P_Identity)
            self.onName = OnName
            self.onToken = OnToken
            self.onVariable = OnVariable
        end

        %%% Get a value from the `referencesLD` attribute, or run the function
        %%% and add it as a reference.
        meth getFromRefOrRun(Key F ?RetVal)
            OldLD NewLD OldVal NewVal IsExisting
        in
            OldLD = referencesLD <- NewLD
            NewLD = {LinearDictionary.condPut OldLD Key ?OldVal NewVal ?IsExisting}
            if IsExisting then
                RetVal = OldVal
            else
                NewVal = {F Key}
                RetVal = NewVal
            end
        end

        %%% Walk on a thing. Return the transformed thing.
        meth walk(Thing ?RetVal)
            RetVal = case {Reflection.getStructuralBehavior Thing}
            of value then
                if {IsName Thing} then
                    {self.onName Thing}
                else
                    Thing
                end
            [] variable then
                {self.onVariable Thing}
            [] token then
                if {IsName Thing} then
                    {self.onName Thing}
                else
                    {self getFromRefOrRun(Thing self.onToken $)}
                end
            [] structural then
                {self getFromRefOrRun(Thing fun {$ R}
                    NewLabel = {self walk({Label R} $)}
                    NewContent = {Map {Record.toListInd R} fun {$ K#V}
                        {self walk(K $)}#{self walk(V $)}
                    end}
                in
                    {List.toRecord NewLabel NewContent}
                end $)}
            end
        end
        %}}}
    end

    fun {P_Identity X} X end

    %%% Encode the "thing" for serialization.
    proc {P_Encode Thing ?VarNames ?TokenNames ?RetVal}
        %{{{
        VarNamesD = {NewDictionary}
        TokenNamesD = {NewDictionary}

        fun {OnVariable Var}
            VarName = if {Reflection.isReflectiveVariable Var} then
                {P_FindNameForVariable Var}
            else
                {New C_ReflectiveVariable initWithVar(Var)}.name
            end
        in
            {Dictionary.put VarNamesD VarName unit}
            VarName
        end

        fun {OnToken Token}
            TokenName = {P_GetTokenName Token}
        in
            {Dictionary.put TokenNamesD TokenName unit}
            TokenName
        end

        Walker = {New C_Walker init(onToken:OnToken onVariable:OnVariable)}
    in
        RetVal = {Walker walk(Thing $)}
        VarNames = {Dictionary.keys VarNamesD}
        TokenNames = {Dictionary.keys TokenNamesD}
        %}}}
    end

    %%% Register a callback to all remote objects represented by the names. The
    %%% callbacks would usually be used to send a command to the remote side.
    %%%
    %%% @param Kind Either 'variable' or 'token'.
    proc {P_RegisterRemoteObjects Kind Names Key Callback Context}
        %{{{
        GD Cls
    in
        case Kind
        of variable then
            GD = G_Variables
            Cls = C_ReflectiveVariable
        [] token then
            GD = G_UnknownTokens
            Cls = C_ReflectiveEntity
        end

        for Name in Names do
            ExistingVar NewVar
        in
            {Dictionary.condExchange GD Name ?ExistingVar _ NewVar}
            if {IsFree ExistingVar} then
                NewVar = {New Cls initWithName(Name)}
            else
                NewVar = ExistingVar
            end
            {NewVar register(Key Callback Context)}
        end
        %}}}
    end

    %%% Decode the "thing" from deserialization.
    fun {P_Decode Thing}
        %{{{
        fun {OnName Name}
            AllDicts = [G_Variables G_UnknownTokens G_KnownTokens]
        in
            for return:R default:Name GD in AllDicts do
                Obj = {Dictionary.condGet GD Name unit}
            in
                if Obj \= unit then
                    {R {Obj getObject($)}}
                end
            end
        end
        Walker = {New C_Walker init(onName:OnName)}
    in
        {Walker walk(Thing $)}
        %}}}
    end


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%% A common class for all those that support a callback.
    class C_ReflectiveCommon
        %{{{
        feat
            %%% The name to identify itself.
            name
            %%% The callbacks to invoke to perform some actions.
            callbacks: {NewDictionary}
            %%% The thread which process the stream of actions.
            streamThread

        meth init(Name Stream)
            self.name = Name
            thread
                self.streamThread = {Thread.this}
                {self processStream(Stream)}
            end
        end

        %%% Register a callback. The callback must be a procedure of the form
        %%%
        %%%     {Callback Key Context ThisName EncodedData VarNames TokenNames}
        %%%
        %%% @param Key A key used in `unregister`. This key must be a feature
        %%%            type, and must not be `unit`.
        %%% @param Context An arbitrary object to pass to the callback
        meth register(Key Callback Context<=unit)
            {Dictionary.put self.callbacks Key Callback#Context}
        end

        %%% Unregister the callback previously added in `register`.
        meth unregister(Key)
            {Dictionary.remove self.callbacks Key}
        end

        %%% Invoke all callbacks on the data. If new variables are generated,
        %%% they will be automatically registered with callbacks here as well.
        meth invokeCallbacks(Data)
            VarNames TokenNames
            EncodedData = {P_Encode Data ?VarNames ?TokenNames}
        in
            for Key#(Callback#Context) in {Dictionary.entries self.callbacks} do
                {P_RegisterRemoteObjects variable VarNames Key Callback Context}
                thread
                    {Callback Key Context self.name EncodedData VarNames TokenNames}
                end
            end
        end

        %%% Terminate the stream-processing thread in this object.
        meth terminateThread
            {Thread.terminate self.streamThread}
        end
        %}}}
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%% Hold a dictionary of reflective variables. Once the reflective variable
    %%% is bound, we will remove it from the dictionary.
    G_Variables = {NewDictionary}

    %%% Find the name of corresponding to a reflective variable. If not found,
    %%% returns `unit` (note: O(n)).
    fun {P_FindNameForVariable ReflVar}
        {ListEx.findFirst {Dictionary.entries G_Variables} fun {$ _#V}
            V.reflVar == ReflVar
        end unit#unit}.1
    end

    %%% A holder of reflective variables. These instances will be added to the
    %%% UnboundVariables dictionary.
    class C_ReflectiveVariable from C_ReflectiveCommon
        %{{{
        feat
            reflVar

        %%% Initialize the reflective variable with a known name.
        meth initWithName(Name)
            Stream
        in
            C_ReflectiveCommon,init(Name Stream)
            self.reflVar = {Reflection.newReflectiveVariable ?Stream}
            {Dictionary.put G_Variables Name self}
        end

        %%% Initialize the reflective variable with a free variable. The
        %%% variable will be bound with the reflective variable of this
        %%% instance.
        meth initWithVar(Variable)
            {self initWithName({NewName})}
            Variable = self.reflVar
        end

        meth processStream(Stream)
            Action#Confirmation = Stream.1
            ShouldContinue
        in
            case Action
            of bind(X) then
                {self bind(X)}
                ShouldContinue = false
            [] markNeeded then
                % what to do with 'markNeeded'??
                {System.show ['markNeeded?' self.name {Thread.this}]}
                {Wait self.reflVar}
                ShouldContinue = false
            else
                {Exception.raiseError unknownAction(Action)}
                ShouldContinue = false
            end
            Confirmation = unit
            if ShouldContinue then
                {self processStream(Stream.2)}
            end
        end

        meth getObject(?R)
            R = self.reflVar
        end

        meth bind(X)
            {self invokeCallbacks(bind(X))}
            {Reflection.bindReflectiveVariable self.reflVar X}
            {Dictionary.remove G_Variables self.name}
        end
        %}}}
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%% Hold a ref-counted dictionary of shared tokens.
    G_KnownTokens = {NewDictionary}

    fun {P_GetTokenName Token}
        %{{{
        Name = {ListEx.findFirst {Dictionary.entries G_KnownTokens} fun {$ _#V}
            V.token == Token
        end unit#unit}.1
    in
        if Name \= unit then
            Name
        else
            Instance = {New C_RefCountedToken init(Token)}
        in
            {Dictionary.put G_KnownTokens Instance.name Instance}
            Instance.name
        end
        %}}}
    end

    proc {P_TokenAddRef Name}
        %{{{
        RefCountedToken = {Dictionary.condGet G_KnownTokens Name unit}
    in
        if RefCountedToken \= unit then
            {RefCountedToken addRef}
        end
        %}}}
    end

    proc {P_PerformAction Name Action KeyToUnregisterOnBind}
        case Action
        of bind(X) then
            ReflectiveVariable = {Dictionary.get G_Variables Name}
        in
            {ReflectiveVariable terminateThread}
            {ReflectiveVariable unregister(KeyToUnregisterOnBind)}
            {ReflectiveVariable bind(X)}
        else
            RefCountedToken = {Dictionary.get G_KnownTokens Name}
            T = RefCountedToken.token
        in
            case Action
            of ':release' then
                if {RefCountedToken release(shouldRemove:$)} then
                    {Dictionary.remove G_KnownTokens Name}
                end
            [] assign(X) then {Assign T X}
            [] isCell(?R) then R = {IsCell T}
            [] access(?R) then R = {Access T}
            [] arrayGet(I ?R) then R = {Get T I}
            [] arrayPut(I V) then {Put T I V}
            [] arrayExchange(I ?O N) then {Array.exchange T I O N}
            [] isArray(?R) then R = {IsArray T}
            [] arrayHigh(?R) then R = {Array.high T}
	    [] arrayLow(?R) then R = {Array.low T}
	    [] send(X) then {Send T X}
            else
                {System.show unknownAction(Action)}
                {Exception.raiseError unknownAction(Action)}
            end
        end
    end

    class C_RefCountedToken
        %{{{
        feat
            name: {NewName}
            token
        attr
            refCount: 1

        meth init(Token)
            self.token = Token
        end

        meth addRef
            OldRC NewRC
        in
            OldRC = refCount <- NewRC
            NewRC = OldRC + 1
        end

        meth release(shouldRemove:?R)
            OldRC NewRC
        in
            OldRC = refCount <- NewRC
            NewRC = OldRC - 1
            R = (NewRC == 0)
        end

        meth getObject(?R)
            R = self.token
        end
        %}}}
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%% Hold a dictionary of reflective entities. Once the reflective entity
    %%% has been garbage-collected, it will invoke the associated finalization
    %%% callback to decrease the reference count of the known token in the
    %%% server.
    G_UnknownTokens = {NewDictionary}
    G_UnknownTokensFinalizationStream
    G_UnknownTokensEntities = {NewWeakDictionary ?G_UnknownTokensFinalizationStream}

    proc {P_DoReleaseUnknownTokens}
        %{{{
        for Name#_ in G_UnknownTokensFinalizationStream do
            Obj = {Dictionary.get G_UnknownTokens Name}
        in
            {Obj terminateThread}
            {Obj invokeCallbacks(':release')}
            {Dictionary.remove G_UnknownTokens Obj.name}
        end
        %}}}
    end

    class C_ReflectiveEntity from C_ReflectiveCommon
        %{{{
        meth initWithName(Name)
            ActionStream
            ReflEntity = {Reflection.newReflectiveEntity ?ActionStream}
        in
            C_ReflectiveCommon,init(Name ActionStream)
            {WeakDictionary.put G_UnknownTokensEntities Name ReflEntity}
        end

        meth processStream(Stream)
            Action#Confirmation = Stream.1
        in
            {self invokeCallbacks(Action)}
            Confirmation = unit
            {self processStream(Stream.2)}
        end

        meth getObject(?R)
            R = {WeakDictionary.condGet G_UnknownTokensEntities self.name self.name}
        end
        %}}}
    end

in
    thread
        {P_DoReleaseUnknownTokens}
    end
end

