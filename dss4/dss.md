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

Fault Stream
------------

(TODO)
