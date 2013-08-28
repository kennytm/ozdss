functor
import
    System
define
    D = {NewDictionary}
    K = {VirtualString.toAtom "omgwtfbbq"}
    L = {VirtualString.toAtom "hahahaha"}
in
    {Dictionary.put D K 1}
    {Dictionary.put D L 2}
    {System.show K < L}
    {System.show {Dictionary.entries D}}
end


