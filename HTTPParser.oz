functor
import
    System
    Pickle
    Space at 'x-oz://boot/Space'
    UUID
    IdentityDictionary

define

    P = {NewDictionary}
    X
    Y
    Z = {NewCell X}
    W = r(Z X Y)
    WW = s(W Z X)
    KK

in
    {System.show WW}
    KK = {PrepareForSending WW P}
    {System.show KK}
    {System.show WW}

    for K#V in {Dictionary.entries P} do
        {System.show {Pickle.pack K}}
        {System.show V.value}
    end
end
