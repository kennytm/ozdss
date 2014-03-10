% This is like Pickle.oz, but has customized routine to handle shared references,
% procedures and mutable objects.

functor
import
    BootSerializer at 'x-oz://boot/Serializer'
    BootGNode at 'x-oz://boot/GNode'
    System

%export
    %Serialize
    %Deserialize

define
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    % Primitive writers
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%% Write a signed integer to a virtual byte string.
    %%%
    %%% This method writes an integer in LEB128 format. This format, as opposed
    %%% to fixed-length format, allows small integers (which is the common case)
    %%% to be encoded in much less space, and also allows arbitrarily large
    %%% integer to be stored (which is required for future expansion).
    %%%
    %%% See also: http://en.wikipedia.org/wiki/LEB128
    %%%
    fun {WriteInt V}
        %%% Encodes a positive integer in LEB128 to a byte-list.
        %%%
        fun {PositiveIntToVBS V}
            % Oz really needs built-in bitwise operation.
            TheByte = V mod 128
            NextValue = V div 128
        in
            if NextValue \= 0 orelse TheByte >= 64 then
                (TheByte + 128) | {PositiveIntToVBS NextValue}
            else
                [TheByte]
            end
        end

        %%% Encodes a negative integer in LEB128 to a byte-list.
        %%%
        fun {NegativeIntToVBS V}
            TheByteNeg = V mod 128
            TheByte = if TheByteNeg < 0 then TheByteNeg + 128 else 0 end
            NextValue = (V - TheByte) div 128
        in
            if NextValue \= ~1 orelse TheByte < 64 then
                (TheByte + 128) | {NegativeIntToVBS NextValue}
            else
                [TheByte]
            end
        end
    in
        if V >= 64 then
            {PositiveIntToVBS V}
        elseif V >= 0 then
            [V]
        elseif V >= ~64 then
            [V + 128]
        else
            {NegativeIntToVBS V}
        end
    end


    %%% Write an unsigned integer to a byte string.
    %%%
    %%% This method writes an integer in ULEB128 format. This format, as opposed
    %%% to fixed-length format, allows small integers (which is the common case)
    %%% to be encoded in much less space, and also allows arbitrarily large
    %%% integer to be stored (which is required for future expansion).
    %%%
    fun {WriteUint V}
        TheByte = V mod 128
        NextValue = V div 128
    in
        if NextValue \= 0 then
            (TheByte + 128) | {WriteUint NextValue}
        else
            [TheByte]
        end
    end


    %%% Write a virtual string to a virtual byte string.
    %%%
    %%% This method encodes the virtual string in UTF-8 format, and return its
    %%% length-prefixed byte string.
    %%%
    fun {WriteVS V}
        BS = {Coders.encode V [utf8]}
    in
        {WriteUint {VirtualByteString.length BS}}#BS
    end


    %%% Write a floating-point number to a virtual byte string.
    %%%
    %%% Currently, this method converts the number to string. In the future, it
    %%% will transmit its IEEE-754 binary64 encoding instead.
    %%%
    fun {WriteFloat V}
        {WriteVS V}
    end

    %%% Write the virtual byte string header of a globalizable object (e.g.
    %%% names, code areas, etc.)
    %%%
    %%% This method will globalize GN and return its UUID.
    %%%
    fun {WriteGNodeHeader GN}
        GNode = {BootGNode.globalize GN}
        UUID = {BootGNode.getUUID GNode}
    in
        UUID
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    % Primitive readers
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%% An input stream backed by a byte string.
    %%%
    class InputStream
        attr
            bs

        meth init(BS)
            bs := BS
        end


        %%% Read a signed integer from the stream head.
        %%%
        %%% The integer should be encoded in LEB128 format. See {WriteInt} for
        %%% detail.
        %%%
        meth readInt(?Result)
            fun {ReadIntInner (H|T) Cur Mult}
                NextMult = Mult * 128
                Next
            in
                if H >= 128 then
                    Next = Cur + (H - 128) * Mult
                    {ReadIntInner T Next NextMult}
                else
                    Next = Cur + H * Mult
                    if H >= 64 then
                        (Next - NextMult)#T
                    else
                        Next#T
                    end
                end
            end
            Result#Rest = {ReadIntInner @bs 0 1}
        in
            bs := Rest
        end


        %%% Read an unsigned integer from the stream head.
        %%%
        %%% The integer should be encoded in ULEB128 format. See {WriteUint} for
        %%% detail.
        %%%
        meth readUint(?Result)
            fun {ReadUintInner (H|T) Cur Mult}
                Next
            in
                if H >= 128 then
                    Next = Cur + (H - 128) * Mult
                    {ReadUintInner T Next (Mult*128)}
                else
                    Next = Cur + H * Mult
                    Next#T
                end
            end
            Result#Rest = {ReadUintInner @bs 0 1}
        in
            bs := Rest
        end


        %%% Read a fixed amount (N) of bytes.
        %%%
        meth readFixedBytes(N ?Result)
            Result
            Rest
        in
            {List.takeDrop @bs N ?Result ?Rest}
            bs := Rest
        end


        %%% Read a single byte.
        %%%
        meth readByte(?Result)
            Result|Rest = @bs
        in
            bs := Rest
        end


        %%% Read a virtual string from the stream head.
        %%%
        meth readVS(?Result)
            StringLength = {self readUint($)}
            Bytes = {self readFixedBytes(StringLength $)}
        in
            Result = {Coders.decode Bytes [utf8]}
        end


        %%% Read a floating-point number from the stream head.
        meth readFloat(?Result)
            Result = {StringToFloat {self readVS($)}}
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    % Oz object writers
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % These common atoms will have special codes to save space.
    SpecialAtoms = a(
        kernel: 241
        boolCaseType: 242
        noElse: 243
        column: 244
        file: 245
        line: 246
        '#': 247
        nil: 248
        false: 249
        true: 250
    )


    class OzWriter from BaseObject
        attr
            output: nil

        meth get(?Result)
            Result = @output
        end

        meth append(VBS typeCode:TypeCode<=unit)
            output := if TypeCode == unit then
                @output#VBS
            else
                @output#[TypeCode]#VBS
            end
        end

        meth appendUint(N)
            {self append({WriteUint N})}
        end

        meth appendVS(VS)
            {self append({WriteVS VS})}
        end

        meth appendNumberTuple(TypeCode Tup options:Options<=nil)
            ShouldSkipWidth = {Member skipWidth Options}
            ShouldSkipTypeCode = {Member skipTypeCode Options}
            WidthBytes = if ShouldSkipWidth then nil else {WriteUint {Width Tup}} end
            TypeCodeBytes = if ShouldSkipTypeCode then nil else [TypeCode] end
            ContentBytes = {Adjoin {Record.map Tup WriteUint} '#'}
        in
            output := @output#TypeCodeBytes#WidthBytes#ContentBytes
        end

        meth int(Val Rec)
            % Perhaps specialize a few numbers here.
            {self Append(1 {WriteInt Val})}
        end

        meth float(Val Rec)
            {self Append(2 {WriteFloat Val})}
        end

        meth bool(Val Rec)
            {self atom(Val Rec)}
        end

        meth 'unit'(Val Rec)
            {self Append(4 nil)}
        end

        meth atom(Val Rec)
            TypeCode = {CondSelect SpecialAtoms Val 5}
            Content = if TypeCode == 5 then {WriteVS Val} else nil end
        in
            {self Append(TypeCode Content)}
        end

        meth cons(Val Rec)
            {self AppendNumberTuple(6 Rec options:[skipWidth])}
        end

        meth tuple(Val Rec)
            {self AppendNumberTuple(7 Rec)}
        end

        meth arity(Val Rec)
            {self AppendNumberTuple(8 Rec)}
        end

        meth record(Val Rec)
            {System.show Rec}
            {self AppendNumberTuple(9 Rec)}
        end

        meth builtin(Val Rec)
            builtin(Mod FuncName) = Rec
        in
            {self Append(10 {WriteVS Mod}#{WriteVS FuncName})}
        end

        meth codearea(Val Rec)
            codearea(Code Arity XCount Ks PrintName DebugData) = Rec
        in
            {self Append(11 {WriteGNodeHeader Val})}
            {self AppendNumberTuple(unit Code options:[skipTypeCode])}
            {self appendUint(Arity)}
            {self appendUint(XCount)}
            {self appendVS(PrintName)}
            {self appendUint(DebugData)}
            {self AppendNumberTuple(unit Ks options:[skipTypeCode])}
        end

        meth abstraction(Val Rec)
            {self Append(16 {WriteGNodeHeader Val})}
            {self AppendNumberTuple(unit Rec options:[skipTypeCode])}
        end
    end

    %%% Try to read a globalized node from BS. If the node did not exist, call
    %%% `ReadFunc`, otherwise, call `SkipFunc`.
    %%%
    %%% ReadFunc should have signature::
    %%%
    %%%     {ReadFunc UUID BS} = Result#Rest
    %%%
    %%% and SkipFunc should have signature::
    %%%
    %%%     {SkipFunc BS} = Rest
    %%%
    fun {ReadGNode BS ReadFunc SkipFunc}
        UUID
        GNode
        Content = {List.takeDrop BS 16 ?UUID}
    in
        if {BootGNode.load UUID ?GNode} then
            GNode#{SkipFunc Content}
        else
            {ReadFunc UUID Content}
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    % Typed writers
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    fun {GenTypeWriteRefs TypeCode ShouldWriteWidth}
        fun {$ _ R}
            HeaderBytes = if TypeCode \= unit then [TypeCode] else nil end
            WidthBytes = if ShouldWriteWidth then {WriteUint {Width R}} else nil end
            ContentBytes = {Adjoin {Record.map R WriteUint} '#'}
        in
            HeaderBytes#WidthBytes#ContentBytes
        end
    end


    fun {TypeWriteAtom A _}
        Type = {CondSelect SpecialAtoms A 5}
    in
        if Type == 5 then
            [Type]#{WriteVS A}
        else
            [Type]
        end
    end



    fun {TypeWriteInt A _}
        % Perhaps we could special-case some numbers here.
        [1]#{WriteInt A}
    end



    fun {TypeWriteCodeArea C codearea(Code Arity XCount Ks PrintName DebugData)}
        GenWriter = {GenTypeWriteRefs unit true}

        UUID = {WriteGNodeHeader C}
        CodeBytes = {GenWriter _ Code}
        % ^ Note that this uses ULEB128 under the hood, so the generated code is
        %   not a 1-to-1-correspondence to the code in memory. Which may be a
        %   good thing, this generally produce a smaller message.
        ArityBytes = {WriteUint Arity}
        XCountBytes = {WriteUint XCount}
        KsBytes = {GenWriter _ Ks}
        PrintNameBytes = {WriteVS PrintName}
        DebugDataBytes = {WriteUint DebugData}
    in
        [11]#UUID#CodeBytes#ArityBytes#XCountBytes#KsBytes#PrintNameBytes#DebugDataBytes
    end



    fun {TypeWriteName N _}
        [19]#{WriteGNodeHeader N}
    end


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    % Real de/serialization
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%%
    %%% Serialize `Obj` into a virtual byte string.
    %%%
    %%% Parameters:
    %%%     OnVariable - A function to be called when a new variable is going to
    %%%                  be serialized. This method should return a unique
    %%%                  integer to identify this variable.
    %%%     OnToken    - A function to be called when a new token (mutable cell)
    %%%                  is going to be serialized. This method should return a
    %%%                  unique integer to identify this token.
    %%%
    fun {Serialize Obj OnVariable OnToken}
        Writer = {New OzWriter noop}
        Serializer = {BootSerializer.new}
        ResultIndex
        Result = {BootSerializer.serialize Serializer [Obj#ResultIndex]}
        NumEntries = Result.1

        proc {WriteAll Entry}
            case Entry
            of Index#Val#Rec#Next then
                MethodName = {Label Rec}
            in
                {System.show Index#Val#Rec#Next}
                {Writer MethodName(Val Rec)}
                {WriteAll Next}
            else
                skip
            end
        end
    in
        {Writer appendUint(NumEntries)}
        {Writer appendUint(ResultIndex)}
        {WriteAll Result}
        {Writer get($)}
    end


    fun {Deserialize BS OnVariable OnToken}
        Stream = {New InputStream init(BS)}
        % This is where variable shadowing like Rust is useful.
        NumEntries = {Stream readUint($)}
        ResultIndex = {Stream readUint($)}
        Nodes = {MakeTuple nodes NumEntries}

        for Index in NumEntries..1;~1 do
            skip
        end
    in
        Nodes.ResultIndex
    end


    %fun {DoSerialize Qs}
    %
    %end


    %proc {Serialize Obj}
    %    N
    %    Qs = {BootSerializer.serialize {BootSerializer.new} [Obj#N]}
    %in
    %    {System.show {DoSerialize Qs}}
    %end

    {System.show {VirtualByteString.toCompactByteString {Serialize
        fun {$ X} X - 2 end
    unit unit}}}
end

