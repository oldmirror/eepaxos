%% takes care of communication with client. Client communication is synchronous. 
-module(eepaxos_frontend).
-include("../include/eepaxos_types.hrl").
-export([block_call/1, async_call/1, cast/1]).

% block the call until the command is commited
block_call(_Command) ->
	ok.

% return asynchronously with key 
%-spec async_call(atom()) -> Key
async_call(_Command) ->
ok.

% asyn
cast(_Command) ->
ok.
