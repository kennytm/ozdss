functor
import
    OS
    System

export
    RandomUUID

define
    % TODO provide bitwise operations in Oz for more general tests.
    %      for now we just assume the numbers are between 0 and 2^32 - 1.
    %      This is always true for the Boost-based VM, but this not a guarantee.
    {OS.randLimits 0 0xffffffff}

    % Convert integer to hex string. Shouldn't this be built-in?
    fun {IntToHex Value Length}
        if Value == 0 andthen Length =< 0 then
            "0"
        else
            CurValue = {NewCell Value}
            CurLength = {NewCell Length}
        in
            for while:(@CurValue \= 0 orelse @CurLength > 0) prepend:P do
                Digit = @CurValue mod 16
            in
                {P [if Digit < 10 then &0 + Digit else &a - 10 + Digit end]}
                CurValue := @CurValue div 16
                CurLength := @CurLength - 1
            end
        end
    end

    % Generate a random version-4 UUID.
    fun {RandomUUID}
        Part1 = {OS.rand}
        Part2 = {OS.rand}
        Part3 = {OS.rand}
        Part4 = {OS.rand}
    in
        {IntToHex Part1 8}#'-'#
                {IntToHex (Part2 div 0x10000) 4}#'-4'#
                {IntToHex (Part2 mod 0x1000) 3}#'-'#
                {IntToHex ((Part3 div 0x40000) + 0x8000) 4}#'-'#
                {IntToHex (Part3 mod 0x10000) 4}#
                {IntToHex Part4 8}
    end
end

