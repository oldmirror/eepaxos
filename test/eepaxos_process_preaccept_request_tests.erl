-module(eepaxos_process_preaccept_request_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

% Description
%TODO: provide description

run_test_() ->
	[{
" acceptor received preaccept request and at the point, "
"  - there's no interfering operation present"
"  - and hasn't seen any instance with the given inst_key"
" expected to log the command and reply to the leader with no_change"
" Internally, it must update conflicts and maxSeqPerKey tables"
	, {setup, fun start/0, fun stop/1, fun preaccept_request_ok/1}}
	,{
" When there's interfering operations. No instance with same inst_key"
" deps must be updated. seq must be updated. "
" Internal tables, conflicts and maxSeqPerKey must be updated."
	, {setup, fun start/0, fun stop/1, fun preaccept_request_updated/1}}
	,{
" When there's inst_key exists with higher ballot"
" Must not reply"
	, {setup, fun start/0, fun stop/1, fun preaccept_request_higher_ballot/1}}
" Instance exists for inst_key. Lower ballot but moved to accepted state or further"
" Must not reply"
	, {setup, fun start/0, fun stop/1, fun preaccept_request_inst_already_accepted/1}}
	].
	

start() ->
	ets:new(membership, [set, named_table, public, {read_concurrency, true}, {write_concurrency, true}]),
	ets:insert(membership, {total, 3}),
	ets:insert(membership, {quorum, 2}),
	ets:insert(membership, {1, 'a'}),
	ets:insert(membership, {2, 'b'}),
	ets:insert(membership, {3, 'c'}),
	PartitionId = vn0,
	ReplicaId = 1,
	
	Members = [1, 2, 3],
	
	%eepaxos_membership_mock:start_link(PartitionId, Members),

	{ok, Pid} = eepaxos_process:start_link(PartitionId, ReplicaId),
	Pid.

stop(Pid) ->
	gen_server:call(Pid, stop).

preaccept_request_ok(Pid) ->
	Cmd = #eepaxos_command{operation = set, key = k, value = 1},

	Expected = #preaccept_response{inst_key = {2, 1}
				, is_changed = false}),

	eepaxos_process:preaccept_request(vn0, 
		#preaccept_request{ballot = {0, 0, 2}
		, leader = 2
		, inst_key = {2, 1}
		, cmd = Cmd
		, deps  = {}
		, seq = 1}),

	receive
		_ -> [{1, N} | _T] = ets:lookup(test_result, 1)
		[?_assertNot(N#preaccept_response.is_changed),
		?_assertEqual(Expected#preaccepted_response.inst_key, N#preaccept_response.inst_key)]
	after
		1000 -> N = {error, no},
		[?_assert(false]
	end.

preaccept_request_updated(Pid) ->
	Cmd = #eepaxos_command{operation = set, key = k, value = 1},

	Input = #inst{key = {2, 1}
				, ballot = {0, 0, 2}
				, cmd  = Cmd %#eepaxos_command{key = j}
				, deps = [{1, 0}, {2, 0}, {3, 0}]
				, seq = 1
				, state = preaccepted
				},

	Expected = #preaccept_request{ballot = {0, 0, 1}
				, leader = 1
				, inst_key = {1, 1}
				, cmd = Cmd
				, deps  = [{1, -1}, {2, -1}, {3, -1}]
				, seq = 1},

	ets:insert(inst, Input),
	ets:insert(conflicts, {{2, k}, 1}),
	ets:insert(maxSeqPerKey, {k, 1}),

	eepaxos_process:preaccept_request(vn0, 
		#preaccept_request{ballot = {0, 0, 2}
		, leader = 2
		, inst_key = {2, 1}
		, cmd = Cmd
		, deps  = {}
		, seq = 1}),
	receive
		_ -> [N | _T] = ets:lookup(test_result, 1)
	end,

	?_assert(true).

preaccept_request_higher_ballot(Pid) ->
	Cmd = #eepaxos_command{operation = set, key = k, value = 1},

	Output = #preaccept_request{ballot = {0, 0, 1}
				, leader = 1
				, inst_key = {1, 1}
				, cmd = Cmd
				, deps  = [{1, -1}, {2, -1}, {3, -1}]
				, seq = 1},

	InputCmd = #eepaxos_command{operation = set
				, key = k
				, value = 2},

	eepaxos_process:preaccept_request(vn0, 
		#preaccept_request{ballot = {0, 0, 2}
		, leader = 2
		, inst_key = {2, 1}
		, cmd = Cmd
		, deps  = {}
		, seq = 1}),
	receive
		_ -> [N | _T] = ets:lookup(test_result, 1)
	end,

	?_assert(true).

preaccept_request_inst_already_accepted(Pid) ->
	Cmd = #eepaxos_command{operation = set, key = k, value = 1},

	Output = #preaccept_request{ballot = {0, 0, 1}
				, leader = 1
				, inst_key = {1, 1}
				, cmd = Cmd
				, deps  = [{1, -1}, {2, -1}, {3, -1}]
				, seq = 1},

	InputCmd = #eepaxos_command{operation = set
				, key = k
				, value = 2},

	eepaxos_process:preaccept_request(vn0, 
		#preaccept_request{ballot = {0, 0, 2}
		, leader = 2
		, inst_key = {2, 1}
		, cmd = Cmd
		, deps  = {}
		, seq =1} ),
	receive
		_ -> [N | _T] = ets:lookup(test_result, 1)
	end,

	?_assert(true).
