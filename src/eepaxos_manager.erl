-module(eepaxos_manager).
-behavior(gen_fsm).
-export([init/1, create/2, start_cluster/0, join/0]).
-export([handle_call/2, handle_cast/2, code_change/3, handle_info/2, terminate/2]).
init([]) ->
	ets:new(partition_info, [set, named_table]),
	ok.

create(PartitionId, NodeList) ->
	{ok, Pid} = supervisor:start_child(eepaxos_process_sup, [PartitionId, NodeList]),
	ets:insert(),
	ok.

start_cluster() -> ok.

join() -> ok.


handle_call({accepting, Msg}, State) ->
	{next_state, accepting, State};
handle_call({joining, Msg}, State) ->
	{next_state, accepting, State}.
handle_cast({mark_dead, Msg}, State) ->
	{next_state, accepting, State};
handle_cast({mark_alive, Msg}, State) ->
	{next_state, accepting, State}.

code_change(_OldVsn, _State, _Extra) -> ok.
handle_info(_Info, _State) -> ok.
terminate(_Reason, _State) -> ok.
