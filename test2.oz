functor
import
    System
    Pickle
define
    D = {NewDictionary}
    K = {NewName}
    L = {NewName}
in
    {Dictionary.put D K 1}
    {Dictionary.put D L 2}
    {System.show {Dictionary.get D {Pickle.unpack {Pickle.pack K}}}}
end


