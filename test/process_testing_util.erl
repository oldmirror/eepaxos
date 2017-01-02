-module(process_testing_util).
-export([start/0, stop/1]).
-define(REPLICA_ID, 1).
start() ->
	ets:new(membership, [set, named_table, public, {read_concurrency, true}, {write_concurrency, true}]),
	ets:insert(membership, {total, 3}),
	ets:insert(membership, {quorum, 2}),
	ets:insert(membership, {1, 'a'}),
	ets:insert(membership, {2, 'b'}),
	ets:insert(membership, {3, 'c'}),
	PartitionId = vn0,
	ReplicaId = ?REPLICA_ID,
	
	Members = [1, 2, 3],
	
	{ok, Pid} = eepaxos_process:start_link(PartitionId, ReplicaId),
	Pid.

stop(Pid) ->
	io:format(user, "stop pid ~w~n", [Pid]),
	ets:delete(membership),
	ets:delete(inst),
	ets:delete(conflicts),
	ets:delete(lbk),
	ets:delete(maxSeqPerKey),
	ets:delete(test_result),
	%exit(Pid, kill).
	gen_server:call(Pid, stop).
