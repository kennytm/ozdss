functor
export
    FindFirst

define
    %%% Find the first element X in the list Xs which satisfies the predicate P.
    %%%
    %%% @param Default The default return value if the element is not found.
    fun {FindFirst Xs P Default}
        case Xs
        of H|T then
            if {P H} then
                H
            else
                {FindFirst T P Default}
            end
        else
            Default
        end
    end
end

