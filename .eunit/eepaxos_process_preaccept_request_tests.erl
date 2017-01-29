-module(eepaxos_process_preaccept_request_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").
-define(ID, eepaxos_processvn0).

% Description
%TODO: provide description

run_test_() ->
	[{
" acceptor received preaccept request and at the point,~n"
"  - there's no interfering operation present~n"
"  - and hasn't seen any instance with the given inst_key~n"
" expected to log the command and reply to the leader with no_change~n"
" Internally, it must update conflicts and maxSeqPerKey tables~n"
	, {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun preaccept_request_ok/1}}
	,{
" When there's interfering operations. No instance with same inst_key"
" deps must be updated. seq must be updated. "
" Internal tables, conflicts and maxSeqPerKey must be updated."
	, {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun preaccept_request_updated/1}}
	,{
" When there's inst_key exists with higher ballot"
" Must not reply"
	, {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun preaccept_request_higher_ballot/1}}
	,{
" Instance exists for inst_key. Lower ballot but moved to accepted state or further"
" Must not reply"
	, {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun preaccept_request_inst_already_accepted/1}}
	].
	
preaccept_request_ok(Pid) ->
	io:format(user, "preaccept_request_ok", []),
	ets:insert(test_result, {2, self()}),

	Cmd = #eepaxos_command{operation = set, key = k, value = 1},

	PAReq =	#preaccept_request{ballot = {0, 0, 2}
		, leader = 2
		, inst_key = {2, 1}
		, cmd = Cmd
		, deps  = []
		, seq = 1},

	Expected = #preaccept_response{inst_key = {2, 1}
				, is_changed = false},

	eepaxos_process:preaccept_request(?ID, PAReq),

	receive
		_ -> [{1, N} | _T] = ets:lookup(test_result, 1),
		io:format(user, "~w", [N]),
		[?_assertNot(N#preaccept_response.is_changed), ?_assertEqual(Expected#preaccept_response.inst_key, N#preaccept_response.inst_key)]
	after
		3000 -> N = {error, no},
		?_assert(false)
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

	eepaxos_process:preaccept_request(?ID, 
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

	eepaxos_process:preaccept_request(?ID, 
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

	Input = #inst{key = {2, 1}
				, ballot = {0, 0, 2}
				, cmd  = Cmd
				, deps = [{1, 0}, {2, 0}, {3, 0}]
				, seq = 1
				, state = accepted
				},

	ets:insert(inst, Input),
	ets:insert(conflicts, {{2, k}, 1}),
	ets:insert(maxSeqPerKey, {k, 1}),

	eepaxos_process:preaccept_request(?ID, 
		#preaccept_request{ballot = {0, 0, 2}
		, leader = 2
		, inst_key = {2, 1}
		, cmd = Cmd
		, deps  = {}
		, seq =1} ),

	Expected = #preaccept_request{ballot = {0, 0, 1}
				, leader = 1
				, inst_key = {1, 1}
				, cmd = Cmd
				, deps  = [{1, -1}, {2, -1}, {3, -1}]
				, seq = 1},

	receive
		_ -> 
			[{1, N} | _T] = ets:lookup(test_result, 1),
			?_assert(false)
	after 
		10000 -> ?_assert(true)
	end.
