functor

import
    Classifier(classify:Classify)
    BootName at 'x-oz://boot/Name'
    OS

export
    Return

define
    Return = classifyTests([
        classifyValueTest(
            proc {$}
                value = {Classify 1.0}
                value = {Classify {NewName}}
                value = {Classify true}
                value = {Classify false}
                value = {Classify unit}
                value = {Classify nil}
                value = {Classify {Pow 2 100}}
                value = {Classify object}
                value = {Classify 'Test漢字テスト'}
                value = {Classify {VirtualString.toCompactString "CompactString"}}
                value = {Classify {BootName.newUnique uniqueName}}
                value = {Classify {BootName.newNamed namedName}}
                value = {Classify {ByteString.make "ByteString"}}
                value = {Classify NewCell}
            end
        )

        classifyCompositeTest(
            proc {$}
                structural = {Classify a(b)}
                structural = {Classify a|nil}
                structural = {Classify [a]}
                structural = {Classify a#b}
                structural = {Classify x(a:b)}
                structural = {Classify "OldString"}
            end
        )

        classifyImmutableTest(
            proc {$}
                immutable = {Classify (proc {$} skip end)}
                immutable = {Classify (fun {$} Return end)}
                immutable = {Classify (class $ meth x skip end end)}
                immutable = {Classify BaseObject}
            end
        )

        classifyMutableTest(
            proc {$}
                mutable = {Classify {NewCell _}}
                mutable = {Classify {NewPort _}}
                mutable = {Classify {New BaseObject noop}}
                mutable = {Classify {NewArray 1 2 unit}}
                mutable = {Classify {NewDictionary}}
                mutable = {Classify OS.stdout}
            end
        )

        classifyVariableTest(
            proc {$}
                variable = {Classify _}
                variable = {Classify {ByNeed NewName}}
            end
        )

        classifyFutureTest(
            proc {$}
                future = {Classify !!_}
                future = {Classify {ByNeedFuture NewName}}
            end
        )
    ])

end

