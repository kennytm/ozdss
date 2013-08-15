This is an implementation of the Oz DSS (Distributive Subsystem) using the Mozart Platform 2.0. It is currently created as an independent project, but will be merged into the main repository when finished.

Note that it is an unfinished project. There is no guarantee that it will work.

How to run the test project
===========================

1. Get the mozart2 from https://github.com:kennytm/mozart2.
2. Fork the `unstable` branch.
3. Build and install.
4. Run the following:

        ozc -c UUID.oz
        ozc -c LinearDictionary.oz
        ozc -c GenericDictionary.oz
        ozc -c ProxyValue.oz
        ozc -c DSSCommon.oz
        ozc -c Connection2.oz

5. Run the ticket server with `./runoz Connection3.oz`.
6. Run the ticket client with `./runoz Connection4.oz`. 
