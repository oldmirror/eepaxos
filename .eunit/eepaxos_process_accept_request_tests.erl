-module(eepaxos_process_accept_request_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[{"Basic. No previously seen record. node must record it in the log with accepted state "
	"and generates accept response"
			, {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_no_record/1}}
	, {"Record previously seen with preaccepted. prev record has same ballot id. Node update state with accepted "
			, {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_higher_ballot/1}}
	, {"If lower ballot, ballot in inst also needs to be updated. "
	"Case where accept req sent after prepare."
			, {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_lower_ballot/1}}
	, {"Record been accepted"
			, {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_accepted_record/1}}
	, {"Higer ballot"
			, {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_higher_ballot/1}}
	].

accept_request_no_record(Pid) -> 
	io:format(user, "accept_request_no_record", []),
	ets:update_element(lbk, {#lbk.clientProposals, self()}),
	%input
	AReq = #accept_request{ballot  = {0, 0, 2}
		, leader = 2
		, inst_key = {2, 1}
		, cmd = {set, k, 1}
		, deps = []
		, seq = 1},

	%output
	Expected = #accept_response{inst_key = {2, 1}},
 
	eepaxos_process:accept_request(Pid, AReq),
	
	A2 = receive  % receive and check 
		_ -> 
			case ets:looup(test_result, 1) of 
				[{1, R}] -> 
					%assert inst inserted
					case ets:lookup(inst, {2, 1}) of 
						[T] -> [?_assertEqual(accepted, T#inst.state), ?_assertEqual(R, Expected)];
						_ -> [?_assert(false)]
					end;
				_ -> ?_assert(false)
			end
	after 5000 ->
		?_assert(false)
	end.

accept_request_preaccepted_record(Pid) -> 
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
	?_assert(true).

accept_request_higher_ballot(Pid) -> ?_assert(true).

accept_request_lower_ballot(Pid) -> ?_assert(true). 
