functor
import
    System

export
    new: GDNew
    condGet: GDCondGet
    put: GDPut
    length: GDLengthEx
    forAllInd: GDForAllIndEx
    remove: GDRemove

define
    % A generic dictionary that can accept any keys with a strict weak ordering,
    % by an arbitrary 'less than' function.
    %
    % The implementation is based on GHC's Data.Map.

    fun {GDNew LessThanFunc}
        unit#LessThanFunc
    end

    fun {GDCondGet RN#LTF Key DefVal}
        case RN
        of n(_ K V Left Right) then
            if {LTF Key K} then
                {GDCondGet Left#LTF Key DefVal}
            elseif {LTF K Key} then
                {GDCondGet Right#LTF Key DefVal}
            else
                V
            end
        else
            DefVal
        end
    end

    fun {GDPut RN#LTF Key Value}
        case RN
        of n(Size K V Left Right) then
            if {LTF Key K} then
                {GDBalance K V {GDPut Left#LTF Key Value}.1 Right}#LTF
            elseif {LTF K Key} then
                {GDBalance K V Left {GDPut Right#LTF Key Value}.1}#LTF
            else
                n(Size Key Value Left Right)#LTF
            end
        else
            n(1 Key Value unit unit)#LTF
        end
    end

    fun {GDLength RN}
        case RN
        of n(Size _ _ _ _) then
            Size
        else
            0
        end
    end

    fun {GDLengthEx RN#_}
        {GDLength RN}
    end

    proc {GDForAllInd RN P}
        case RN
        of n(_ K V Left Right) then
            {GDForAllInd Left P}
            {P K V}
            {GDForAllInd Right P}
        else
            skip
        end
    end

    proc {GDForAllIndEx RN#_ P}
        {GDForAllInd RN P}
    end

    fun {GDRemove RN#LTF Key}
        case RN
        of n(_ K V Left Right) then
            if {LTF Key K} then
                {GDBalance K V {GDRemove Left#LTF Key}.1 Right}#LTF
            elseif {LTF K Key} then
                {GDBalance K V Left {GDRemove Right#LTF Key}.1}#LTF
            else
                {GDGlue Left Right}#LTF
            end
        else
            RN#LTF
        end
    end

    GDDelta = 5
    GDRatio = 2

    fun {GDBalance K V Left Right}
        LeftLength = {GDLength Left}
        RightLength = {GDLength Right}
        NewLength = LeftLength + RightLength + 1
        DefaultReturn = n(NewLength K V Left Right)
    in
        if NewLength > 2 then
            if RightLength >= GDDelta * LeftLength then
                {GDRotateLeft K V Left Right}
            elseif LeftLength >= GDDelta * RightLength then
                {GDRotateRight K V Left Right}
            else
                DefaultReturn
            end
        else
            DefaultReturn
        end
    end

    fun {GDNode K V Left Right}
        NewLength = 1 + {GDLength Left} + {GDLength Right}
    in
        n(NewLength K V Left Right)
    end

    fun {GDRotateLeft K V Left Right}
        n(_ RK RV RLeft RRight) = Right
    in
        if {GDLength RLeft} < GDRatio * {GDLength RRight} then
            {GDNode RK RV {GDNode K V Left RLeft} RRight}
        else
            n(_ RLK RLV RLLeft RLRight) = RLeft
        in
            {GDNode RLK RLV {GDNode K V Left RLLeft} {GDNode RK RV RLRight RRight}}
        end
    end

    fun {GDRotateRight K V Left Right}
        n(_ LK LV LLeft LRight) = Left
    in
        if {GDLength LRight} < GDRatio * {GDLength LLeft} then
            {GDNode LK LV LLeft {GDNode K V LRight Right}}
        else
            n(_ LRK LRV LRLeft LRRight) = LRight
        in
            {GDNode LRK LRV {GDNode LK LV LLeft LRLeft} {GDNode K V LRRight Right}}
        end
    end

    fun {GDGlue Left Right}
        Key
        Value
    in
        if Left == unit then
            Right
        elseif Right == unit then
            Left
        elseif {GDLength Left} > {GDLength Right} then
            NewLeft = {GDRemoveFindMax Left ?Key ?Value}
        in
            {GDBalance Key Value NewLeft Right}
        else
            NewRight = {GDRemoveFindMin Right ?Key ?Value}
        in
            {GDBalance Key Value Left NewRight}
        end
    end

    fun {GDRemoveFindMin RN ?Key ?Value}
        n(_ K V Left Right) = RN
    in
        if Left == unit then
            Key = K
            Value = V
            Right
        else
            NewLeft = {GDRemoveFindMin Left ?Key ?Value}
        in
            {GDBalance K V NewLeft Right}
        end
    end

    fun {GDRemoveFindMax RN ?Key ?Value}
        n(_ K V Left Right) = RN
    in
        if Right == unit then
            Key = K
            Value = V
            Left
        else
            NewRight = {GDRemoveFindMax Right ?Key ?Value}
        in
            {GDBalance K V Left NewRight}
        end
    end
end

