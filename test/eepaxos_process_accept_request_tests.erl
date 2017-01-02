-module(eepaxos_process_accept_request_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[{"basic. No previously seen record. node must record in inst with accepted state"
	"and generates accept response", {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_no_record/1}}
	, {"Record previously seen with preaccepted. Node update state with accepted "
			, {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_higher_ballot/1}}
	, {"If lower ballot, ballot in inst also needs to be updated. "
	"Case where accept req sent after prepare. ", {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_lower_ballot/1}}
	, {"Record been accepted", {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_accepted_record/1}}
	, {"Higer ballot", {setup, fun process_testing_util:start/0
			, fun process_testing_util:stop/1
			, fun accept_request_higher_ballot/1}}
	].

accept_request_no_record(Pid) -> 
	eepaxos_process:accept_request(Pid, #accept
	AR = #accept_request{ballot  = {0, 0, 2}
		, leader = 2
		, inst_key {2, 1}
		, cmd = {set, k, 1}
		, deps = []
		, seq = 1},
	
	Expected = #accept_response{ inst_key = {2, 1}},
	%assert inst insterted
	A1 = case ets:lookup(inst, {2, 1}) of 
		[T] -> ?_assertEqual(accepted, T#inst.state);
		_ -> ?_assert(false)
	end
	
	A2 = receive  % receive and check 
		_ -> 
			case ets:looup(test_result, 1) of 
				[{1, R}] -> ?_assertEqual(R, Expected);
				_ -> ?_assert(false).
			end
	after 5000 ->
		?_assert(false).
	end,
	A1 ++ A2.

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
			,originaldeps
			,committeddeps
			,preparing = false
			,clientProposals  
			}),

	?_assert(true).

accept_request_accepted_record(Pid) -> 
	?_assert(true).

accept_request_higher_ballot(Pid) -> ?_assert(true).

accept_request_aft
