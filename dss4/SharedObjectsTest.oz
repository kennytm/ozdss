functor

import
    SharedObjects
    System
    WeakReference at 'x-oz://boot/WeakReference'

export
    Return

define
    proc {ClearXRegs}
        proc {F X1 X2 X3 X4 X5 X6 X7 X8 X9 X10}
            skip
        end
    in
        {F 0 0 0 0 0 0 0 0 0 0}
    end

    Return = sharedObjectsTests([
        %%% Just to record how to properly (?) test if a weakref works.
        weakRefSanityTest(proc {$}
            WR
        in
            {proc {$}
                WR = {WeakReference.new {NewCell 1}}
            end}
            {proc {$}
                some(_) = {WeakReference.get WR}
                {ClearXRegs}
            end}
            {System.gcDo}
            {proc {$}
                none = {WeakReference.get WR}
            end}
        end)

        varEqSanityTest(proc {$}
            A = _
            B = _
            C = A
        in
            true = {System.eq A A}
            false = {System.eq A B}
            true = {System.eq A C}
            B = unit % silence warning.
        end)

        %%% Test that linking to objects correctly reports the names and status.
        linkTest(proc {$}
            SO = {New SharedObjects.sharedObjects init}
            Object1 = {NewCell 1}
            Object2 = {NewCell 2}
            Name1
            Name2
        in
            new = {SO link(object:Object1 link:a name:?Name1 status:$)}
            old = {SO link(object:Object1 link:a name:Name1 status:$)}
            nonlocal = {SO link(object:Object1 link:b name:Name1 status:$)}
            new = {SO link(object:Object2 link:a name:?Name2 status:$)}
            true = (Name1 \= Name2)
        end)

        linkVarTest(proc {$}
            SO = {New SharedObjects.sharedObjects init}
            Object1 = _
            Object2 = _
            Name1
            Name2
            Name3
        in
            new = {SO link(object:Object1 link:a name:?Name1 status:$)}
            old = {SO link(object:Object1 link:a name:Name3 status:$)}
            nonlocal = {SO link(object:Object1 link:b name:Name1 status:$)}
            new = {SO link(object:Object2 link:a name:?Name2 status:$)}
            true = (Name1 \= Name2)
            true = (Name1 == Name3)
            true = {IsName Name1}
            true = {IsName Name2}
            Object2 = unit % silence warning
        end)

        %%% Test that an object is removed after all links disappeared.
        unlinkTest(proc {$}
            SO = {New SharedObjects.sharedObjects init}
            ObjectName
            WR
        in
            {proc {$}
                Object1 = {NewCell 1}
            in
                WR = {WeakReference.new Object1}
                {SO link(object:Object1 link:a name:?ObjectName status:new)}
                {SO link(object:Object1 link:b name:ObjectName status:nonlocal)}
            end}

            {proc {$}
                {SO unlink(link:a name:ObjectName)}
                {ClearXRegs}
            end}

            {System.gcDo}

            {proc {$}
                {WeakReference.get WR} = some(_)
                {ClearXRegs}
            end}

            {proc {$}
                {SO unlink(link:b name:ObjectName)}
                {ClearXRegs}
            end}

            {System.gcDo}

            {proc {$}
                {WeakReference.get WR} = none
            end}
        end)

        disconnectTest(proc {$}
            SO = {New SharedObjects.sharedObjects init}
            WRs = [_ _ _]

            proc {Check Ls}
                [true true true] = {List.zip Ls WRs (fun {$ L WR}
                    L == {Label {WeakReference.get WR}}
                end)}
                {ClearXRegs}
            end
        in
            {proc {$}
                WRs = for collect:C I in 0..2 do
                    Obj = {NewCell I}
                in
                    {C {WeakReference.new Obj}}
                    {SO link(object:Obj link:I name:_ status:_)}
                    {SO link(object:Obj link:((I+1) mod 3) name:_ status:_)}
                end
            end}

            % 0 <- [0 1]
            % 1 <- [1 2]
            % 2 <- [2 0]

            {proc {$}
                {SO disconnect(link:0)}
                {ClearXRegs}
            end}

            {System.gcDo}

            {proc {$}
                {Check [some some some]}
            end}

            % 0 <- [1]
            % 1 <- [1 2]
            % 2 <- [2]

            {proc {$}
                {SO disconnect(link:1)}
                {ClearXRegs}
            end}

            {System.gcDo}

            {proc {$}
                {Check [none some some]}
            end}

            % 0 <- nil
            % 1 <- [2]
            % 2 <- [2]

            {proc {$}
                {SO disconnect(link:4)}
                {ClearXRegs}
            end}

            {System.gcDo}

            {proc {$}
                {Check [none some some]}
            end}

            % 0 <- nil
            % 1 <- nil
            % 2 <- nil

            {proc {$}
                {SO disconnect(link:2)}
                {ClearXRegs}
            end}

            {System.gcDo}

            {proc {$}
                {Check [none none none]}
            end}
        end)
    ])
end

