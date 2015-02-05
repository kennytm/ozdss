functor

import
    Pickle
    BootSerializer at 'x-oz://boot/Serializer'
    System
    Classifier
    PickleResource
    Reflection at 'x-oz://boot/Reflection'

export
    Serialize
    Deserialize

define
    proc {PrintTypes S}
        case S
            of I#V#K#Rest then
                {System.show I#K#V}
                {PrintTypes Rest}
            [] nil then
                skip
        end
    end

    fun {CollectNonValues Obj LinkName Repository}
        SpecialObjects
    in
        %{PrintTypes {BootSerializer.serialize {BootSerializer.new} [Obj#_]}}

        SpecialObjects = {BootSerializer.extractByLabels Obj Classifier.specialTypes}

        for collect:C SubObj#Type in SpecialObjects do
            Status ObjName Replacement ObjClass
        in
            {Repository link(object:SubObj link:LinkName name:?ObjName status:?Status)}
            % Perform replacement if:
            %  - it is not a function, or
            %  - it is a function, but has been sent to the same link before.
            if {Label Type} \= abstraction orelse Status == old then
                ObjClass = {Classifier.classify SubObj}
                Replacement = {PickleResource.new ObjName ObjClass}
                {C (SubObj#Replacement)}
            end
        end
    end

    %%% Serializes an object. The resulting virtual byte string can then be sent
    %%% through wires.
    %%%
    %%% Parameters:
    %%%
    %%% * Obj --- The object to serialize.
    %%% * LinkName --- A unique name within this VM to identify the peer to send
    %%%                the object to.
    %%% * Repository --- A SharedObjects instance to register any non-values.
    fun {Serialize Obj LinkName Repository}
        TemporaryReplacements = {CollectNonValues Obj LinkName Repository}
    in
        {Pickle.packWithReplacements Obj TemporaryReplacements}
    end

    %%% Deserialize an object from a virtual-byte-string.
    %%%
    %%% All non-values will be transformed into using the function F. The
    %%% function should have signature:
    %%%
    %%%     fun {F ObjectName ObjectKind}
    %%%         {CreateReflectiveObjectFor ObjectName ObjectKind}
    %%%     end
    %%%
    fun {Deserialize VBS F}
        UnpackRes = {Pickle.unpack VBS}
        AllChunks = {BootSerializer.extractByLabels UnpackRes r(chunk:unit)}
    in
        for Ch#_ in AllChunks do
            if {PickleResource.is Ch} then
                {PickleResource.substitute Ch F}
            end
        end
        UnpackRes
    end
end

