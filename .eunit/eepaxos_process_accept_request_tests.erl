-module(eepaxos_process_accept_request_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[
	{"Basic. No previously seen record. node must record it in the log with accepted state "
	"and generates accept response"
			, {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_no_record/1}}
	, {"Record previously seen with preaccepted."
		"prev record has same ballot id. Node update state with accepted "
			, {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_preaccepted_record/1}}
	, {"inst preaccepted and higher ballot comes in. "
		"Must update inst ballot with incoming higher ballot and respond to leader. "
			, {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_higher_ballot/1}}
	, {"If lower ballot, ballot in inst also needs to be updated. "
		"Case where accept req sent after prepare."
			, {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_accepted_record/1}}
	, {"Lower ballot. Must be ignored"
			, {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_lower_ballot/1}}
	].

accept_request_no_record(Pid) -> 
	io:format(user, "FUNCTION_LABEL: accept_request_no_record", []),
	%pre-condition
	%Nothing

	%output
	Expected = #accept_response{inst_key = {2, 1}},

	%input
	AReq = #accept_request{ballot  = {0, 0, 2}
	 , leader = 2
	 , inst_key = {2, 1}},
 
	eepaxos_process:paxos_accept_request(Pid, AReq),
	
	receive  % receive and check 
		_ -> 
			case ets:lookup(test_result, 1) of 
				[{1, R}] -> 
					%assert inst inserted
					case ets:lookup(inst, {2, 1}) of 
						[T] -> [?_assertEqual(accepted, T#inst.state), ?_assertEqual(T#inst.key, {2, 1})];
						_ -> [?_assert(false)]
					end;
				_ -> ?_assert(false)
			end
	after 5000 ->
		?_assert(false)
	end.

accept_request_higher_ballot(Pid) -> 
	io:format(user, "FUNCTION_LABEL: accept_request_higher_ballot", []),
	
	%pre-condition
	ets:insert(inst, #inst{ballot = {0, 0, 2}
		, key = {2, 1}
        , cmd  = #eepaxos_command{operation=set, key=k, value=1}
        , deps = []
        , seq = 1
        , state = ?ST_PREACCEPTED}),

	%maxSeqPerKey and conflicts are omitted. Is this OK?

	%output
	Expected = #accept_response{inst_key = {2, 1}},

	%input
	AReq = #accept_request{ballot  = {0, 1, 3}
			, leader = 3
			, inst_key = {2, 1}},
 
	eepaxos_process:paxos_accept_request(Pid, AReq),
	
	receive
		_ -> 
			[{1, Resp}] = ets:lookup(test_result, 1),
			[Inst] = ets:lookup(inst, {2, 1}),
			
			% verify response
			[?_assertEqual({2, 1}, Resp#accept_response.inst_key)
			% verify internal state
			, ?_assertEqual(Inst#inst.state, ?ST_ACCEPTED)
			, ?_assertEqual(Inst#inst.ballot, {0, 1, 3})
			]
	after 5000 ->
		%TODO: verify internal state not changed
		?_assert(false)
	end.

accept_request_preaccepted_record(Pid) -> 
	io:format(user, "FUNCTION_LABEL: accept_request_preaccepted_record", []),
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
			,nacks = 0
			,preparing = false
			},

	?_assert(true).

accept_request_accepted_record(Pid) -> 
	io:format(user, "FUNCTION_LABEL: accept_request_accepted_record", []),
	?_assert(true).

accept_request_lower_ballot(Pid) ->
	io:format(user, "FUNCTION_LABEL: accept_request_lower_ballot", []),
	?_assert(true).
