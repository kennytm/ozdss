functor
import
    System

define
    WD = {NewWeakDictionary _}
    X

in
    {WeakDictionary.close WD}

    local
        for I in 1..100 do
            {WeakDictionary.put WD I {NewName}}
        end
        {System.show {WeakDictionary.keys WD}}
    end

    thread
        {System.gcDo}
        X = unit
    end

    {Wait X}

    {System.show {WeakDictionary.keys WD}}
end

