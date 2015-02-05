functor

export
    ToLittleEndianBytes
    FromLittleEndianBytes

define
    %%% Convert an unsigned 32-bit integer to little-endian list of bytes.
    %%%
    %%% Example:
    %%%
    %%% ```
    %%% {ToLittleEndianBytes 0x1234 4} = [0x34 0x12 0 0]
    %%% ```
    fun {ToLittleEndianBytes I Width}
        C = {NewCell I}
    in
        for collect:K _ in 1..Width do
            V = @C
        in
            {K (V mod 256)}
            C := V div 256
        end
    end


    %%% Convert a virtual byte string into an unsigned 32-bit integer.
    %%%
    %%% Example:
    %%%
    %%% ```
    %%% {FromLittleEndianBytes [0x34 0x12 0 0]} = 0x1234
    %%% ```
    fun {FromLittleEndianBytes VBS}
        M = {NewCell 1}
    in
        for sum:S B in {VirtualByteString.toList VBS} do
            V = @M
        in
            {S B*V}
            M := V * 256
        end
    end
end

