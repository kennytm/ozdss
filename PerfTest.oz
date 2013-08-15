functor
import
    GenericDictionary
    LinearDictionary

define
    C = {NewCell {LinearDictionary.new}}
    %C = {IdentityDictionary.new}

    for I in 1 .. 50 do
        C := {LinearDictionary.put @C I*I I}
    end

end

