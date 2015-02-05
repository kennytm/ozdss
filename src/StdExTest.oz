functor

import
    StdEx

export
    Return

define
    Return = stdExTests([
        toLittleEndianBytesTest(
            proc {$}
                [0 0 0 0] = {StdEx.toLittleEndianBytes 0 4}
                [255 0 0 0] = {StdEx.toLittleEndianBytes 255 4}
                [0 1 0 0] = {StdEx.toLittleEndianBytes 256 4}
                [0x34 0x12 0 0] = {StdEx.toLittleEndianBytes 0x1234 4}
                [0x78 0x56 0x34 0x12] = {StdEx.toLittleEndianBytes 0x12345678 4}
                [0x10 0xef 0xcd 0xab] = {StdEx.toLittleEndianBytes 0xabcdef10 4}
            end
        )

        fromLittleEndianBytesTest(
            proc {$}
                0x1234 = {StdEx.fromLittleEndianBytes [0x34 0x12 0 0]}
                0xabcdef10 = {StdEx.fromLittleEndianBytes [0x10 0xef 0xcd 0xab]}
            end
        )
    ])

end


