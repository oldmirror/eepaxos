%% takes care of communication with client. Client communication is synchronous. 
-module(eepaxos_client_proxy).
-include("../include/eepaxos_types.hrl").
-export([block_call/2, async_call/2, cast/2]).

% block the call until the command is commited
block_call(PartitionId, _Command) ->
	ok. %ddeepaxos_proces:().

% return asynchronously with key 
%-spec async_call(atom()) -> Key
async_call(PartitionId, _Command) ->
ok.

% asyn
cast(PartitionId, _Command) ->
ok.
