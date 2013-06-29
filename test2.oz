functor
import
    System
    Application
    DPDefaults
define
    Res
in
    {DPDefaults.init}
    Res = {Resolve "oz-site://[fe80:5::4e8d:79ff:fee1:fe1c]:9000/h3968883"}
    {System.showInfo Res}
    {Application.exit 0}
end


