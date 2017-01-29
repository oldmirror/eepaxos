-module(eepaxos_mod_execution).

execute(Mod, Cmd) ->
	Mod:execute(Cmd).
