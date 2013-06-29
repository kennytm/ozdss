%%%
%%% Author:
%%%   Kenny Chan <kennytm@gmail.com>
%%%
%%% Copyright:
%%%   Kenny Chan, 2013
%%%
%%% Last change:
%%%   $Date$ by $Author$
%%%   $Revision$
%%%
%%% This file is part of Mozart, an implementation of Oz 3:
%%%   http://www.mozart-oz.org
%%%
%%% See the file "LICENSE" or
%%%   http://www.mozart-oz.org/LICENSE.html
%%% for information on usage and redistribution
%%% of this file, and for a DISCLAIMER OF ALL
%%% WARRANTIES.
%%%

functor
import
    DPDefaults

export
    OfferOnce
    OfferMany
    Take

define
    {DPDefaults.init}

    fun {Take Ticket}
        SitePath TicketID
    in
        {ParseTicket Ticket ?SitePath ?TicketID}
    end

%{{{ Implementation ------------------------------------------------------------

    AllIPs = {DPDefaults.doGetIp
                {Value.condSelect {Property.get 'dp.listenerParams'} ip best}
             }

    % Generate a unique ticket for others to take.
    fun {MakeTicket}
        unit
    end

    % Input: A ticket of the form 'oz-ticket://path#1234'
    % Output: A pair (x#y), the first element being the 'path', and the second
    %         being the
    proc {ParseTicket Ticket ?SitePath ?TicketID}
        TicketString = {VirtualString.toString Ticket}
    in
        % Not using compact string until we have compact string literal.
        if {List.isPrefix "oz-ticket://" TicketString} then
            UriWithoutScheme = {List.drop TicketString {Length "oz-ticket://"}}
            Fragment = {String.token UriWithoutScheme &# ?SitePath}
            TicketID = {String.toInt Fragment}
        else
            {Exception.raiseError dp(ticket parse TicketString)}
        end
    end

%}}}

end

