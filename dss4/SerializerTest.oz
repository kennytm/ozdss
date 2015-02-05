functor

import
    Serializer(serialize:Serialize deserialize:Deserialize)
    SharedObjects
    System
    OS

export
    Return

define
    proc {RunTest ThingsToSerialize PostDeserializeTest}
        LinkName = test
        SO = {New SharedObjects.sharedObjects init}
        VBS = {Map ThingsToSerialize (fun {$ X} {Serialize X LinkName SO} end)}
        Res
    in
        true = {All VBS IsVirtualByteString}

        Res = {Map VBS (fun {$ X}
            {Deserialize X (fun {$ N C} {SO get(name:N object:$)} end)}
        end)}

        {PostDeserializeTest VBS Res}
    end

    fun {SampleFun A B}
        A + B
    end

    Return = serializerTests([
        valueTest(
            proc {$}
                A = a(b:A c:~{Pow 2 100} d:0.25 e:[false true#unit])
            in
                {RunTest [A] (proc {$ _ [A2]}
                    A = A2
                end)}
            end
        )

        cellTest(
            proc {$}
                A = {NewCell 123}
            in
                {RunTest [A] (proc {$ _ [A2]}
                    A = A2
                    @A2 = 123
                end)}
            end
        )

        chunkTest(
            proc {$}
                A = {NewChunk a(b:c)}
            in
                {RunTest [A] (proc {$ _ [A2]}
                    true = (A \= A2)
                    % Chunks are not specially managed by DSS. Thus, the
                    % deserialization will create a distinct chunk.
                    true = {IsChunk A2}
                    c = A2.b
                end)}
            end
        )

        % To test that all mutables are handled.
        otherMutablesTest(
            proc {$}
                A = [
                    {NewArray 1 10 unit}
                    {NewDictionary}
                    {NewPort _}
                    {New BaseObject noop}
                    %{Thread.this}   % FIXME cannot send a thread (but does this even make sense?)
                    OS.stdout
                ]
            in
                {RunTest A (proc {$ _ A2}
                    A = A2
                end)}
            end
        )

        varTest1(
            proc {$}
                A
            in
                {RunTest [A] (proc {$ _ [A2]}
                    A2 = 192
                    true = (A == 192)
                end)}
            end
        )


        varTest2(
            proc {$}
                A D
            in
                {RunTest [A#D#A] (proc {$ _ [A2]}
                    B#C#E = A2
                in
                    D = 5555
                    B = 7777
                    true = (A == 7777)
                    true = (C == 5555)
                    true = (E == 7777)
                end)}
            end
        )

        futureTest(
            proc {$}
                A
                B = !!A
            in
                {RunTest [B] (proc {$ _ [B2]}
                    true = {IsFuture B2}
                    A = 441
                    true = (B == 441)
                    true = (B2 == 441)
                end)}
            end
        )

    /*
        % Doesn't work, causes segfault in mozartvm.

        procSanityTest(
            proc {$}
                {RunTest [SampleFun SampleFun] (proc {$ [VBS1 VBS2] [F1 F2]}
                    true = {VirtualByteString.length VBS1} > {VirtualByteString.length VBS2}
                    F1 = SampleFun
                    F2 = SampleFun
                    F1 = F2
                    {F1 123 551} = 674
                end)}
            end
        )
    */


    /*
        procTest(
            proc {$}
                fun {SampleFun A B}
                    A + B
                end

                VBS1
                VBS2
                LinkName = {NewName}
                Thread1Done
                Thread2Done
            in
                thread
                    VBS1 = {Serialize SampleFun }
                    VBS2 = {Serialize SampleFun }
            end
        )

        classTest(
            proc {$}
                class SampleClass
                    feat
                        a: 123
                        b
                    meth init(B)
                        self.b = B
                    end

                    meth compute(?R)
                        R = self.a + self.b
                    end
                end

                VBS1
                VBS2
                LinkName = {NewName}
                Thread1Done
                Thread2Done
            in
                thread
                    VBS1 = {Serialize SampleClass LinkName}
                    VBS2 = {Serialize SampleClass LinkName}
                    true = ({VirtualByteString.length VBS1} > {VirtualByteString.length VBS2})
                    Thread1Done = unit
                end

                thread
                    C1 = {Deserialize VBS1}
                    C2 = {Deserialize VBS2}
                    Inst
                in
                    true = (C1 == C2)
                    Inst = {New C2 init(451)}
                    574 = {Inst compute($)}
                    Thread2Done = unit
                end

                true = (unit == Thread1Done)
                true = (unit == Thread2Done)
            end
        )
        */
    ])
end

