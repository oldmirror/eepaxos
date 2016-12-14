-module(eepaxos_membership).
-behavior(gen_fsm).
-export([]).
-export([]).
-export([]).
-record(state, {members = []
				, alive_members = []
				, order_map = []
				, quorum_num = 1
				, fast_quorum_num = 1
				}).

join() -> ok.
remove() -> ok.
init([]) ->
	ok.

handle_call(state) ->
	
	{next_state, '', State}

handle_info() ->
	ok.

node_down(State) ->
	State1 = State#state{alive_members = 
		lists:[])
	
	State1.
