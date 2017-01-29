-module(eepaxos_process_accept_response_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[{"Basic case. Commit request is expected"
		, {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun accept_response_all_resp/1}}
	, {"ignore additional"
		, {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun accept_response_ignore_additional/1}}
	, {"all_resp case but it's not original leader"
		, {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun accept_by_other_leader/1}}
	].

accept_response_all_resp(Pid) ->
	io:format(user, "accept_response_all_resp", []),
	Cmd = #eepaxos_command{operation = set, key = k, value = 1},

	Inst = #inst{key = {1, 1}
			, ballot = {0, 0, 0}
			, cmd  = Cmd
			, deps = []
			, seq = 1
			, state = accepted},
		
	Lbk = #lbk{key = {1, 1}
			,prepareoks = 0
			,allequal = true
			,preacceptoks = 0
			,acceptoks = 1
			,preparing = false
			},

	ets:insert(inst, Inst),
	ets:insert(lbk, Lbk),
	%ets:insert(conflicts, {}),
	%ets:insert(maxSeqPerKey, {}),

	eepaxos_process:accept_response(Pid, #accept_response{inst_key = {1, 1}}),
	Expected = #commit_request{inst_key = {1, 1}
				, cmd = Cmd
				, deps = []
				, seq = 1},

	receive
		_ ->
			case ets:lookup(test_result, 1) of
				[{1, T}] -> [?_assertEqual(Expected, T)];
				_-> ?_assert(false)
			end
		after 5000 ->
			?_assert(false)
	end.

accept_response_nack(Pid) -> ?_assert(true).

accept_response_ignore_additional(Pid) ->
	Cmd = #eepaxos_command{operation = set, key = k, value = 1},
	Inst = #inst{key = {1, 1}
			, ballot = {0, 0, 0}
			, cmd  = Cmd
			, deps = []
			, seq = 1
			, state = committed},
		
	Lbk = #lbk{key = {1, 1}
			,prepareoks = 0
			,allequal = true
			,preacceptoks = 0
			,acceptoks = 1
			,preparing = false
			},

	ets:insert(inst, Inst),
	ets:insert(lbk, Lbk),
%	ets:insert(conflicts, {}),
%	ets:insert(maxSeqPerKey, {}),

	eepaxos_process:accept_response(Pid, #accept_response{inst_key = {1, 1}}),
	receive
		_ ->
			case ets:lookup(test_result, 1) of
				_->?_assert(false)
			end
		after 5000 ->
			?_assert(true)
	end.

accept_by_other_leader(Pid) ->
	
	?_assert(true).
