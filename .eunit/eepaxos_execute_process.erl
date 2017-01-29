-module(eepaxos_execute_process).
-include("../include/eepaxos_types.hrl").
-export([execute/1, strong_component/3]).

execute(Key) ->
	[R] = ets:lookup(inst, Key),
	if R#inst.state == executed -> 
			ok;
		true -> strong_component([], 1, Key)
	end.

strong_component(List, Index, Key) ->
	error_logger:info_msg("strong_compoenent() called. index: ~w, Stack: ~w, Key: ~w", [Index, List, Key]),
	% visiting node, log index, lowlink, and onstack
	ets:update_element(inst, Key, [{#inst.index, Index}
						, {#inst.lowlink, Index}
						, {#inst.onstack, true}]), 

	List1 = lists:append([Key], List),
	
	[Elem] = ets:lookup(inst, Key),
	Deps = Elem#inst.deps,
	error_logger:info_msg("deps ~w, list1 ~w", [Deps, List1]),

	List2 = lists:foldr(fun(Dep, ListAcc) ->  
		error_logger:info_msg("foldr deps ~w", [Dep]),
		
		DepElem = ets:lookup(inst, Dep), % lookup next elem

		if DepElem =/= false andalso DepElem#inst.state =:= executed -> % already handled
				ignore,
				ListAcc;

			DepElem =:= false orelse DepElem#inst.state =/= committed -> % need to wait on this
				timer:sleep(500),
				ListAcc;
				
			DepElem#inst.index =:= undefined -> % not yet visited
				ListNext = strong_component(ListAcc, Index + 1, DepElem#inst.key),

				NewLL = ets:lookup_element(inst, DepElem#inst.key, DepElem#inst.lowlink),

				case NewLL < ets:lookup_element(inst, Key, #inst.lowlink) of
					true -> ets:update_element(inst, Key, {#inst.lowlink, NewLL})
				end,
				ListNext;

			DepElem#inst.onstack =:= true ->

				NewLL = ets:lookup_element(inst, DepElem#inst.key, DepElem#inst.lowlink),

				case NewLL < ets:lookup_element(inst, Key, #inst.lowlink) of
					true -> ets:update_element(inst, Key, {#inst.lowlink, NewLL})
				end,
				ListAcc;
			true -> 
				error,
				ListAcc
		end
	end, List1, Deps),

	case ets:lookup_element(inst, Key, #inst.lowlink) =:= Index of % root of the scc
		true -> 
			% slice and sort the list and execute 
			{List3, ExecList} = lists:split(Index-1, List2),
		
			lists:foreach(fun(Elem) -> 
				error_logger:info_msg("executed"),
				ets:update_element(inst, Key, {#inst.state, executed})
				%execute(Elem)
			end, lists:sort(ExecList)),
			List3;
		_-> List2
	end.
