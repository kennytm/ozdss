functor

import
    Reflection at 'x-oz://boot/Reflection'

export
    Classify
    SpecialTypes

define
    %%% A record of types which needs to be treated specially. This record is to
    %%% be used in `Pickle.packWithReplacements`.
    SpecialTypes = r(
        cell:unit
        array:unit
        dictionary:unit
        port:unit
        object:unit
        'thread':unit
        value:unit % ForeignPointer
        abstraction:unit
    )

    %%% Classifies an object into one of the 6 object classes in DSS.
    %%%
    %%% Example:
    %%%
    %%% ```
    %%% value = {Classify 1.0}
    %%% structural = {Classify [2 3]}   % should never happen after serialization
    %%% immutable = {Classify (proc {$} skip end)}
    %%% mutable = {Classify {NewCell 0}}
    %%% variable = {Classify _}
    %%% future = {Classify !!_}
    %%% ```
    fun {Classify Obj}
        case {Reflection.getStructuralBehavior Obj}
        of token then
            case {Value.type Obj}
            of name then
                value
            [] procedure then
                immutable
            [] 'class' then
                immutable
            else
                mutable
            end
        [] variable then
            if {IsFuture Obj} then
                future
            else
                variable
            end
        [] B then
            B
        end
    end
end

