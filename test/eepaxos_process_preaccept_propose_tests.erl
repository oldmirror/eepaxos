-module(eepaxos_process_preaccept_propose_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").
-define(REPLICA_ID, 1).

% Description
% Test output from propose request. Process module ough to generate preaccept_request with deps and seq based on current state
% which is set by this test cases
run_test_() ->
	[{"propose is ", {setup, fun start/0, fun stop/1, fun preaccept_fresh/1}}
	,{"there's interfering instance.", {setup, fun start/0, fun stop/1, fun propose_interfering_one/1}}].

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
	%exit(Pid, kill).
	gen_server:call(Pid, stop).

% With no depedency, process generates message with no deps and seq as 1.
preaccept_fresh(Pid) ->
	Cmd = #eepaxos_command{operation = set, key = k, value = 1},

	Output = #preaccept_request{ballot = {0, 0, 1}
				, leader = ?REPLICA_ID
				, inst_key = {?REPLICA_ID, 1}
				, cmd = Cmd
				, deps  = [{1, -1}, {2, -1}, {3, -1}]
				, seq = 1}, % minimun sequence

	InputCmd = #eepaxos_command{operation = set
				, key = k
				, value = 2},

	eepaxos_process:propose(Pid, self(), InputCmd),

	receive
		_ -> [{1, N} | _T] = ets:lookup(test_result, 1),
		[?_assert(lists:any(fun({2, -1}) -> true; (_) -> false end, N#preaccept_request.deps)),
		?_assertEqual(1,  N#preaccept_request.seq)]

	after 10000 -> 
		N = {error, no},
		[?_assert(false)]
	end.


propose_interfering_one(Pid) ->
	Cmd = #eepaxos_command{operation = set, key = k, value = 1},

%=====================================
% configure precondition
%=====================================
	Input = #inst{key = {2, 1}
				, ballot = {0, 0, 2}
				, cmd  = Cmd %#eepaxos_command{key = j}
				, deps = [{1, 0}, {2, 0}, {3, 0}]
				, seq = 1
				, state = preaccepted
				},

	ets:insert(inst, Input),
	ets:insert(conflicts, {{2, k}, 1}),
	ets:insert(maxSeqPerKey, {k, 1}),

%=====================================

	Output = #preaccept_request{ballot = {0, 0, 1}
				, leader = ?REPLICA_ID
				, inst_key = {?REPLICA_ID, 1}
				, cmd = Cmd
				, deps  = [{1, -1}, {2, 1}, {3, -1}]
				, seq = 1}, % minimun sequence

	InputCmd = #eepaxos_command{operation = set
				, key = k
				, value = 2},

	eepaxos_process:propose(Pid, self(), InputCmd),

	receive
		_ -> [{1, N} | _T] = ets:lookup(test_result, 1),
		[?_assert(lists:any(fun({2, 1}) -> true; (_) -> false end, N#preaccept_request.deps))]

	after 10000 -> 
		N = {error, no},
		?_assert(false)
	end.
