-module(eepaxos_db_util).


increment_preaccepted(InstKey) -> ok.

get_instance(InstKey) ->
	case ets:lookup(inst, InstKey) of
		[I | T] -> I;
		_ -> false
	end.

get_lbk(InstKey) ->
	case ets:lookup(inst, InstKey) of
		[I | T] -> I;
		_ -> false
	end.
