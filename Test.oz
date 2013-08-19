functor
import
    Reflection at 'x-oz://boot/Reflection'
    System

define
    S
    X = {Reflection.newReflectiveEntity ?S}

    thread
        for A#C in S do
            {System.show A}
            C = unit
        end
    end

    R = {Access X}


end

