functor
export
    new: NewIdentityDictionary

define
    %%% A "dictionary" keyed based on identity only. This "dictionary" allows
    %%% chunks to be keys. But this "dictionary" is O(N).
    class IdentityDictionary from BaseObject
        attr
            list: nil

        meth get(Key ?Value)
            Value = for default:notFound return:R K#V in @list do
                if K == Key then
                    {R ok(V)}
                end
            end
        end

        meth find(KeyPred ?Value)
            Value = for default:notFound return:R K#V in @list do
                if {KeyPred K} then
                    {R ok(V)}
                end
            end
        end

        meth remove(Key)
            list <- {Filter @list fun {$ K#_} K \= Key end}
        end

        meth put(Key Value)
            {self remove(Key)}
            list <- (Key#Value)|@list
        end

        meth condPut(Key DefaultValueFunction ?NewValue)
            NewValue = case {self get(Key $)}
            of ok(V) then V
            else
                NewValue
            in
                % Create the new item _before_ invoking the function, to avoid
                % the function modifying this dictionary again.
                list <- (Key#NewValue)|@list
                NewValue = {DefaultValueFunction Key}
                NewValue
            end
        end

        meth values
            {Map @list fun {$ _#V} V end}
        end
    end

    fun {NewIdentityDictionary}
        {New IdentityDictionary noop}
    end
end
