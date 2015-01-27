Distributed Programming in Mozart 2.0
=====================================

Object types
------------

In DSS, there are 5 classes of objects:

* **Values.**

    These include integers, records, atoms, byte codes (codearea), built-ins
    etc. These objects are immutable with deep equality and therefore can be
    safely copied to the receivers without any callbacks.

* **Immutable objects.**

    <span style="color:red">**Procedures are not yet supported. The VM is
    crashing with them.**</span>

    These include chunks and procedures (abstractions). These types are
    supported by Pickle, but do not admit deep equality. Since we need to
    maintain the identity (name) of these objects, we only copy the object in
    the first send for each connection. Starting from the second send, we could
    transmit the name of the object instead.

    Functors and classes are special cases of chunks.

    We still transmit a copy for immutable objects because otherwise it means
    procedures will not be executed on the client's machine, which defeats the
    whole purpose of DSS.

* **Mutable objects.**

    These include arrays, dictionaries and in general all concrete objects not
    supported by Pickle. These objects are identified entirely by its name only.

    In order to allow the receivers perform action on these shared mutables
    naturally, these objects will be constructed as Reflective Entities. They
    will also create an additional one-way connection back to the sender, to
    report any actions performed.

    There is no need to replace objects on the sender with Reflective Entities.

    Mutable objects are similar to "Stationary objects" in Mozart 1.

* **Plain variables.**

    Plain variables are identified by name only. Variables can be bound once to
    become any object (could be another variable). As binding can happen
    anywhere, we need to replace the variable with Reflective Variables in both
    the sender and receivers.

* **Futures.**

    Unlike plain variables, futures can only be bound from one node. Binding
    will block until the variable protected by the future is bound. Therefore,
    one does not need to create Reflective Variables for futures. Instead, the
    futures on the receiver side will just be bound to a hidden plain variable.
    The sender will wait for the future to be bound (in a new thread), which the
    value will be broadcast to all receivers.

Additionally, there are some object classes in Mozart 1.4 which will not be
supported at the moment:

* **Cached objects.**

    Originally includes cells and OO objects. These objects will be copied when
    execution is needed. This allows repeated access to the same object to use
    less bandwidth. But this may require CRDTs to ensure proper synchronization
    of values. Also, copying cannot be done generally, so each type requires
    special functions to be able to become cached objects.

* **Sequential asynchronous stationary objects.**

    Compared with cached objects, SASOs are not difficult to implement, but it
    still requires some extra configuration which we will delay its
    implementation.

Name Registry
-------------

The objects' associated names have to be stored somewhere. This section shows
how the names are registered for each class of objects.

* **Mutable objects.**

    In the sender side, when we encounter a mutable object, first look up if we
    have already registered it with a name. If no, then do register a new name
    for it. The receiver will construct a Reflective Entity using this name. The
    receiver would also register this name with the Reflective Entity in case it
    would like to forward the object to other nodes.

    The registry should be global among the whole process. In Mozart 2, the
    GNode is a built-in mechanism for registering anything with a name. In fact,
    it is already used in Pickle to ensure unpickling the same procedure won't
    result in distinct objects.

* **Plain variables.**

    This is similar to mutable objects, but we perform the look up only if it is
    a Reflective Variable.

    Once a Reflective Variable is bound (receiving a "bound" message), we could
    drop its name in the process.

* **Futures.**

    While the future itself will not be transmitted, the underlying variable
    will still be named. The registry should be the same as plain variables'.

* **Immutable objects.**

    Immutable objects are tricky as we need to send the copy in the first time
    and the name in the second time onwards. That means the registry have to be
    localized per connection.

    Whenever we send an immutable object, we look up registry of the receiver
    for that object. If no such object exists, send the copy and register the
    name. Otherwise, just send the name. The receiver will also register the
    object on the registry of the sender.

Using the new PackWithReplacements method, one could serialize these objects as
names without modifying the objects themselves.

Garbage Collection
------------------

As the objects are shared among multiple computers, even if one node's GC
indicates an object should be removed, it could still be required by the client.

For values, there is no special GC treatment since they are copied. But for
other classes, we do need special treatment: we cannot remove an object until
all remote sites have finished using that name.

Therefore, every time we sent a name, the remote site have to put it into a weak
dictionary to monitor its lifetime. Once that object is dead (in the post-mortem
phase), the receiver needs to send a message back to the sender indicating that
name is no longer used.

The sender shall keep a list of active connections associated to a name. Until
the list is empty, the entity of that name must still be kept alive.

Receivers may forward a name further away.

Failure model
-------------

We use the same (?) failure model as in Mozart 1.4. Every shared object will
have an associated fault stream.

When an object is set into `localFail` state by `{DP.break}`, any action on it
will automatically wait forever, even if the fault stream says it is "ok". See
the "ac" request in the protocol for detail.

Protocol
--------

Data are sent as reliable, stateless, atomic, unordered packets in a duplex
channel. Each packet is encoded like:

    [2 byte tag] [pickled content]

The packet protocol should encode the length and checksum independently, if
applicable. The packet API should contain the reply address of the peer.

Possible tags are:

* **"tk"** — Take. The content must be an integer, the ticket ID. Ask the peer
  for a value identified by the ticket ID (the fragment part of the ticket URL).

  The ticket URL looks like `oz-dss-tcp://130.104.228.81:9000/h9323679#42`. The
  fragment part "42" is the ticket ID. The host is used by the client to know
  how to connect to the server. The path is ignored, but could be used by
  reverse proxy server to identify the correct process to forward the connection
  to.

* **"of"** — Offer. Reply of a Take request. The content is should be look like:

        TicketID#Value

  The value make contain mutable objects, immutable objects or variables.

  Before pickling in the sender side, they must be extracted into the name
  registry. All of these objects will be linked to the receiver for GC purpose.

        MutableObject   -> {NewChunk dss('dss_obj':Name)}
        ImmutableObject -> {NewChunk dss('dss_proc':Name)}
        PlainVariable   -> {NewChunk dss('dss_var':Name)}
        Future          -> {NewChunk dss('dss_fut':Name)}

  After unpickling in the receiver side, these objects are turned into
  reflective entities/variables. All of them will also be added to a weak
  dictionary, where at post-mortem a GC notification will be sent back to the
  sender.

  If no corresponding ticket ID was found the value will be an error value which
  will raise an exception when used.

* **"gc"** — Garbage collection. A shared entity is no longer needed by
  the sender. The content must be the name of the entity to be disposed:

        EntityName

  The receiver should remove the link associated between the object and the
  sender. This may trigger further GC requests down the chain.

  Only bearer of reflective entities are supposed to send "gc" requests. The
  owner of the original object cannot GC it.

* **"ac"** — Action. Perform some action on a reflective entity. The content
  must be in the form

        EntityName#Action(P1 P2 P3 ...)

  Here `Action(P1 P2 P3 ...)` is the action code supplied by the reflective
  system. For instance, `{Send ReflPort Msg}` is encoded as `PortName#send(Msg)`.
  The inner parameters are serialized like the **"of"** request. Therefore, this
  may further create lots of objects.

  There is no reply to this request. If a reply is needed, one of the parameters
  would be a plain variable. The receiver will use the **"ac"** request again
  with a "bind" action to provide the reply. Therefore, all operations in the
  reflective entity side will always succeed, and results will arrive
  asynchronously.

  If a "bind" action is received, the corresponding reflective variable should
  be replaced by that value, and the action should be forwarded to all linked
  sites (except the sender).

  If the entity of that name is not found in the receiver, it should do nothing.
  In particular, this will effectively hang the sender when used on a localFail
  object, if the action has a return value. However, other sites will not know
  this name has disappeared. They could even get "ok" from the fault stream.
  Perhaps the "tempFail" info should be transitive across sites, but that would
  make the ping/heartbeat message extremely huge. Thus I keep ok/tempFail a
  connection-wise property.

  The sender may be connected to more than one server, which received the same
  entity from all of them (possible with a "diamond" configuration). In such
  case, the message will be forwarded to the site with the most recent "ok"
  status. The same message will only be sent once, to avoid the same action
  being done twice by the owner.

* **"pn"** — Ping. The content should be a sequence number.

        PingID

  Check if the peer is still alive. Also used to determine the response time of
  the peer. Sent when there is not enough messages received from recently. If
  the ping request is not responded in time, the sender should append `tempFail`
  to the fault streams of all objects associated with the link of the receiver.

  A ping request is sent every 5 seconds (?) after the last message is received.
  If the there is no further message in (mean + 2×stdev) of the round-trip time,
  with an initial value of 0.5s, we assume the receiver is `tempFail`. Receiving
  non-heartbeats from the peer does *not* mean it is `ok`, since it is possible
  that they can talk to us but we cannot talk to them.

* **"hb"** — Heartbeat. Reply of a ping request. The content should be the
  sequence number of the ping.

        PingID

  When a ping is sent, we store the PingID and the send-time in a LRU cache.
  Heartbeat received with an unknown PingID is ignored.

* **"ki"** — Kill. Makes an object `permFail`. The content should be the name of
  the object.

        EntityName

  Unrecognized objects are ignored. Kill requests are forwarded to other sites.
  The object should be removed from the name registry after it is killed. This
  effecitvely also GCs the associated object.

* All other tags are simply dropped. They may be added for future expansion.

In pseudocode:

    loop
        ClientAddr#(Tag#ContentBytes) = {RecvPacket Server}
        case Tag
            of "tk" then
                TicketID = {UnpickleAsInt ContentBytes}
                Obj = {Get TicketStore TicketID}
                if Obj is valid then
                    Serialized = {PickleAndLink Obj downlink:ClientAddr}
                    {SendPacket Client "of"#Serialized}
                else
                    {SendPacket Client "of"#ErrValue(nooffer)}
                end
            [] "of" then
                TicketID#Value = {UnpickleWithLink ContentBytes uplink:ClientAddr}
                {AssignTicket TicketID Value}
            [] "gc" then
                EntityName = {UnpickleAsName ContentBytes}
                {UnlinkName EntityName downlink:ClientAddr}
                if {Empty {GetDownLinks EntityName}} then
                    {RemoveName EntityName}
                end
            [] "ac" then
                EntityName#Action = {UnpickleWithLink ContentBytes uplink:ClientAddr}
                % ... if EntityName does not exist then continue.
                case {Label Action}
                    of 'send' then
                        {Send {GetEntity EntityName} Action.1}
                    [] ...
                    [] 'bind' then
                        {GetVariable EntityName} = Action.1
                        % ^ use reflective bind on reflective variable.
                        for Link in {GetUpLinks EntityName} ++ {GetDownLinks EntityName} do
                            if Link \= ClientAddr then
                                {SendPacket Link "ac"#ContentBytes}
                            end
                        end
                end
            [] "pn" then
                {SendPacket ClientAddr "hb"#ContentBytes}
                thread
                    {Delay ClientAddr.rtt}
                    for FaultStream in {GetFaultStreams link:ClientAddr} do
                        FaultStream.2 = sendFail
                    end
                end

            [] "hb" then
                update rtt of ClientAddr
                cancel that thread above
                for FaultStream in {GetFaultStreams link:ClientAddr} do
                    FaultStream.2 = ok
                end
            [] "ki" then
                EntityName = {UnpickleAsName ContentBytes}
                {RemoveName EntityName}
                for Link in {GetUpLinks EntityName} ++ {GetDownLinks EntityName} do
                    if Link \= ClientAddr then
                        {SendPacket Link "ki"#ContentBytes}
                    end
                end
            else
                skip
        end
    end

    % Port-mortem of reflective entities (also means all downlinks are gone)
    proc {Finalize EntityName}
        for Uplink in {GetUpLinks EntityName} do
            {SendPacket Uplink "gc"#EntityName}
        end
        {RemoveName EntityName}
    end

    % Reflective callback
    proc {ReflectiveCallback EntityName Action}
        Uplink = {MinBy {GetUpLinks EntityName} fun{$ X} X.rtt end}
        Action = {PickleAndLink Action downlink:Uplink}
        % ^ no typo here. some kind of contravariance I guess.
        {SendPacket Uplink "ac"#Action}
        case Action of bind(_) then
            {RemoveName EntityName}
        end
    end


### Example interaction

```oz
% server
local
    FS
    P = {NewPort ?FS}
in
    {DisplayToTheWorld {OfferMany P}}
    % ^ suppose it is `oz-ticket://192.168.1.1:24680/#1`
    for do
        {Send P "Hello world"}
    end
    % ^ set up the "hello world" server
end

% client
local
    P = {Take "oz-ticket://192.168.1.1:24680/1"}
    Msg = {Send P}
in
    {Show {Wait Msg}}
end
```

The protocol would be like:

    server                              client

    listen on :24680                    listen on :13579
    create ticket 1 = P
                                        connect to 192.168.1.1:24680
                                        send "tk" (1)
    recv "tk" (1)
    found object P
    serialize P
    notice a mutable object P
    give P a name "1234"
    link "1234" with "192.168.1.2:13579"
    send "of" (Chunk(dss_mut:"1234"))
                                        recv "of" (Chunk(dss_mut:"1234"))
                                        turn into reflective entity "1234".
                                        call {Send P ?Msg}
                                        become reflective call "1234"#send(?Msg)
                                        serialize "1234"#send(?Msg)
                                        notice a plain variable ?Msg
                                        give ?Msg a name "5678"
                                        link "5678" with "192.168.1.1:24680"
                                        send "ac" (Chunk(dss_mut:"1234")#send(Chunk(dss_var:"5678")))

    recv "ac" ("1234"#send("5678"))
    found "1234" as P, no need to create reflective entity
    create reflective entity for "5678"
    link "5678" with "192.168.1.1:24680"
    call {Send P "5678"}

    unify "5678" with string "Hello world!"
    become reflective bind "5678"#bind("Hello world!")
    close fault stream of "5678"
    locally bind "5678"
    send "ac" (Chunk(dss_var:"5678")#bind("Hello world!"))

                                        recv "ac" (Chunk(dss_var:"5678")#bind("Hello world!"))
                                        found "5678" as an existing variable
                                        close fault stream of "5678"
                                        locally bind "5678"
                                        (no other links to "5678" other than the receiver)
                                        (no need to forward the "ac" message)

                                        "Hello world!"


