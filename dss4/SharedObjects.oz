functor

import
    System

export
    SharedObjects

define
    %%% A repository of shared objects.
    %%%
    %%% Instances of this class will act as a "GC root" for some objects shared
    %%% externally. Those objects can be registered here with the names of the
    %%% links associated. Once all associated links are detached, the object
    %%% will be freed from this "GC root", to let the built-in GC to collect it.
    %%%
    class SharedObjects
        prop locking

        feat
            % The 'Name -> Obj' dictionary.
            %
            % We could have used GNode, however, the interface seems not
            % flexible enough for our use.
            %
            % TODO: Find some way to avoid the *linear* lookup. Currently this
            %       is implemented as a singly-linked list of tuples. Since the
            %       objects are not literal, we cannot use Dictionary. We need
            %       an equivalent of IdentityHashMap here!
            objects

            % The 'Name -> [Link]' dictionary.
            %
            % TODO: We could replace the Links list with a ref-count + LRU.
            links

            % The 'Name -> Port' dictionary. The port for fault streams.
            faultStreams

        meth init
            self.objects = {NewDictionary}
            self.links = {NewDictionary}
            self.faultStreams = {NewDictionary}
        end

        %%% Registers the object as part of this repository. If the object has
        %%% already been registered, nothing will happen. Returns the registered
        %%% name of the object.
        %%%
        %%% The result status can be:
        %%% - `new`: The object is entirely new. It has not been registered
        %%%          before.
        %%% - `nonlocal`: The object has been registered before for other links.
        %%%               But it is still the first time registered for the
        %%%               given link.
        %%% - `old`: The object has been registered before.
        %%%
        %%% This method should be used before sending a non-value off the site.
        %%%
        %%% It is not guaranteed that the returning status is precise. It is
        %%% possible that an `old` object is reported `nonlocal`. This
        %%% non-guarantee allows us to use small fast but lossy/probabilistic
        %%% structure to track links. Nevertheless, a `nonlocal` object will
        %%% never be reported `old`, and these are also guaranteed mutually
        %%% exclusive with `new`. The Name reported is always correct.
        meth link(object:Obj link:LinkName name:?Name status:?Status)
            lock
                Entries = {Dictionary.entries self.objects}
            in
                if (for default:true return:R OldName#Object in Entries do
                    if {System.eq Obj Object} then
                        OldLinks NewLinks
                    in
                        Name = OldName
                        {Dictionary.exchange self.links OldName ?OldLinks ?NewLinks}
                        if {Member LinkName OldLinks} then
                            NewLinks = OldLinks
                            Status = old
                        else
                            NewLinks = LinkName|OldLinks
                            Status = nonlocal
                        end
                        {R false}
                    end
                end) then
                    Name = {NewName}
                    Status = new
                    {Dictionary.put self.objects Name Obj}
                    {Dictionary.put self.links Name [LinkName]}
                    {Dictionary.put self.faultStreams Name ok|_}
                end
            end
        end

        %%% Makes an object no longer needed by the link.
        %%%
        %%% This should be called when it receives a GC notification from the
        %%% remote site. When all links associated with the object are removed,
        %%% this repository will free that object.
        meth unlink(link:LinkName name:Name)
            lock
                OldLinks NewLinks
            in
                {Dictionary.condExchange self.links Name nil ?OldLinks ?NewLinks}
                NewLinks = {List.subtract OldLinks LinkName}
                if NewLinks == nil then
                    FS
                in
                    {Dictionary.remove self.links Name}
                    {Dictionary.remove self.objects Name}
                    {self closeFaultStream(Name)}
                end
            end
        end

        %%% Unlinks all objects associated with the given link.
        meth disconnect(link:LinkName)
            lock
                for Name#OldLinks in {Dictionary.entries self.links} do
                    if OldLinks == [LinkName] then
                        {Dictionary.remove self.links Name}
                        {Dictionary.remove self.objects Name}
                        {self closeFaultStream(Name)}
                    else
                        {Dictionary.put self.links Name {List.subtract OldLinks LinkName}}
                    end
                end
            end
        end

        %%% Obtains the object given the name.
        %%%
        %%% If the object does not exist, it will be filled with `unit`.
        meth get(name:Name object:?Object)
            Object = {Dictionary.condGet self.objects Name unit}
        end

        meth getFaultStream(name:Name stream:?Stream)
            FS
        in
            _#FS = {Dictionary.get self.faultStreams Name}
            Stream = !!FS
        end

        meth closeFaultStream(Name)
            FS
        in
            _#FS = {Dictionary.get self.faultStreams Name}
            FS.2 = nil
            {Dictionary.remove self.faultStreams Name}
        end

        meth setStatusForLink(link:LinkName status:Status)
            lock
                for Name#FS in {Dictionary.entries self.faultStreams} do
                    NewTail = Status|_
                    FS.2 = NewTail
                    {Dictionary.put Name NewTail}
                end
            end
        end
    end
end

