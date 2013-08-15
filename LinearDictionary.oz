functor
export
    new: LDNew
    condGet: LDCondGet
    condExchange: LDCondExchange
    condPut: LDCondPut
    put: LDPut
    remove: LDRemove
    length: LDLength

define
    % A generic dictionary that can accept any keys with an equality operator.
    % This dictionary is O(N) in all operations. Please GenericDictionary if a
    % strict weak ordering can be defined.

    fun {LDNew}
        nil
    end

    fun {LDCondGet LD Key DefValue}
        case LD
        of K#V|Tail then
            if K == Key then
                V
            else
                {LDCondGet Tail Key DefValue}
            end
        else
            DefValue
        end
    end

    fun {LDPut LD Key Value}
        case LD
        of K#V|Tail then
            if K == Key then
                K#Value|Tail
            else
                K#V|{LDPut Tail Key Value}
            end
        else
            [Key#Value]
        end
    end

    fun {LDCondExchange LD Key DefValue ?OldValue NewValue}
        case LD
        of K#V|Tail then
            if K == Key then
                OldValue = V
                K#NewValue|Tail
            else
                K#V|{LDCondExchange Tail Key DefValue ?OldValue NewValue}
            end
        else
            OldValue = DefValue
            [Key#NewValue]
        end
    end

    fun {LDCondPut LD Key ?OldValue NewValue ?Existing}
        case LD
        of K#V|Tail then
            if K == Key then
                Existing = true
                OldValue = V
                K#NewValue|Tail
            else
                K#V|{LDCondPut Tail Key ?OldValue NewValue ?Existing}
            end
        else
            Existing = false
            [Key#NewValue]
        end
    end

    fun {LDRemove LD Key}
        {Filter LD fun {$ K#_} K \= Key end}
    end

    LDLength = Length
end

