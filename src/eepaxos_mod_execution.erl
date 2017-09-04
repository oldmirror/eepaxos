-module(eepaxos_mod_execution).


%gives op no and command
execute(Mod, OpNo, Cmd) ->
	Mod:execute(Cmd).

% eepaxos notifies client app that checkpoint happens which discards log. Client app choose to 
% write down the snapshot to the disk
-callback
checkpoint(ChkPnt) ->
	
ok.

% sync node and return checkpoint number
node_sync() ->
	{true, 1}.
