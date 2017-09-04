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
" When there's inst_key exists with lower ballot"
" Must not reply"
	, {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun preaccept_request_lower_ballot/1}}
	,{
" Instance exists for inst_key. higher ballot but moved to accepted state or further"
" Must not reply"
	, {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun preaccept_request_inst_already_accepted/1}}
	].
	
preaccept_request_ok(Pid) ->
	io:format(user, "FUNCTION_LABEL: preaccept_request_ok", []),

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
		io:format(user, "FUNCTION_LABEL: ~w", [N]),
		Result  = [
		?_assertNot(N#preaccept_response.is_changed)
		, ?_assertEqual(Expected#preaccept_response.inst_key, N#preaccept_response.inst_key)
		],

		% check state of eepaxos_process

		% 1) instance is logged
		[M] = ets:lookup(inst, {2, 1}),

		?_assertEqual(M#inst.cmd, Cmd),
		?_assertEqual(M#inst.deps, []),
		?_assertEqual(M#inst.seq, 1),
		?_assertEqual(M#inst.state, preaccepted),
		
		% 2) conflict table is updated with instanceNo
		[{{2, k}, L}] = ets:lookup(conflicts, {2, k}),


		% 3) maxSeqPerKey table
		O = ets:lookup(maxSeqPerKey, k),

		[
		?_assertEqual(N#preaccept_response.is_changed, no_change)
		, ?_assertEqual(Expected#preaccept_response.inst_key, N#preaccept_response.inst_key)
		, ?_assertEqual([{k, 1}], O)
		, ?_assertEqual(L, 1)
		]
	after
		3000 -> N = {error, no},
		?_assert(false)
	end.

preaccept_request_updated(Pid) ->
	io:format(user, "FUNCTION_LABEL: preaccept_request_updated", []),
	Cmd1 = #eepaxos_command{operation = set, key = k, value = 1},
	Cmd2 = #eepaxos_command{operation = inc, key = k, value = 1},

	Input = #inst{key = {2, 1}
				, ballot = {0, 0, 2}
				, cmd  = Cmd1 %#eepaxos_command{key = j}
				, deps = []
				, seq = 1
				, state = preaccepted % preaccepted and above
				},

	ets:insert(inst, Input),
	ets:insert(conflicts, {{2, k}, 1}),
	ets:insert(maxSeqPerKey, {k, 1}),
	
	PAReq = #preaccept_request{ballot = {0, 0, 3}
				, leader = 3
				, inst_key = {3, 1}
				, cmd = Cmd2
				, deps  = [{2, 1}]
				, seq = 2},

	eepaxos_process:preaccept_request(?ID, PAReq),

	receive
		_ -> [N] = ets:lookup(test_result, 1),
			% response comes back with 
			[
			?_assertEqual(N#preaccept_response.inst_key, {2, 1})
			, ?_assertEqual(N#preaccept_response.deps, [{2, 1}])
			, ?_assertEqual(N#preaccept_response.seq, 2)
			, ?_assertEqual(N#preaccept_response.is_changed, changed)
			]
	after 3000 ->
		?_assert(false)
	end,

	?_assert(true).

preaccept_request_lower_ballot(Pid) ->
	io:format(user, "FUNCTION_LABEL: preaccept_request_lower ballot", []),
	Cmd = #eepaxos_command{operation = set, key = k, value = 1},

	Prev = #inst{ballot = {0, 1, 3}
		, key = {2, 1}
		, cmd = Cmd
		, deps  = []
		, seq = 1
		, state = preaccepted},

	ets:insert(inst, Prev),
	ets:insert(conflicts, {{2, k}, 1}),
	ets:insert(maxSeqPerKey, {k, 1}),

	eepaxos_process:preaccept_request(?ID, 
		#preaccept_request{ballot = {0, 0, 2}
				, leader = 2
				, inst_key = {2, 1}
				, cmd = Cmd
				, deps  = []
				, seq = 1}),
	receive
		_ -> 
			?_assert(false)
	after 4000 -> 
			%[N] = ets:lookup(test_result, 1), 
			M = ets:lookup(inst, {2, 1}),
			L = ets:lookup(conflicts, {2, k}),
			O = ets:lookup(maxSeqPerKey, k),
%TODO: more asserts about inst and conflicts could come.
			[?_assertEqual([{k, 1}], O)]
	end.

preaccept_request_inst_already_accepted(Pid) -> %higher ballot
	io:format(user, "FUNCTION_LABEL: preaccept_request_inst_already_accepted", []),
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
			?_assert(false)
	after 
		10000 -> 
			%TODO: verify internal state hasn't changed
			[?_assert(true)]
	end.

% what about higher ballot and not accepted? 
% inst must be updated with incoming one.
preaccept_request_inst_exists_preaccepted(Pid) -> %higher ballot
	io:format(user, "FUNCTION_LABEL: preaccept_request_isnt_exists_preaccepted", []),
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

