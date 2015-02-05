functor

import
    BootName at 'x-oz://boot/Name'
    Reflection at 'x-oz://boot/Reflection'

export
    New
    Is
    Substitute

define
    PickleResourceID = {BootName.newUnique dssPickleResource}

    fun {New ObjName ObjClass}
        {NewChunk dss(PickleResourceID:(ObjName#ObjClass))}
    end

    fun {Is C}
        {IsChunk C} andthen {HasFeature C PickleResourceID}
    end

    proc {Substitute C F}
        ObjName#ObjClass = C.PickleResourceID
    in
        {Reflection.become C {F ObjName ObjClass}}
    end
end


