-module(eepaxos_process_prepare_start_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[{"prepare_start", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun prepare_start_nochange/1}}
	, {"prepare_start", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun prepare_start_change/1}}
	].

prepare_start_nochange(Pid) -> 
	io:format(user, "prepare_start_nochange~n", []),
	?_assert(true).

prepare_start_change(Pid) ->
	io:format(user, "prepare_start_change~n", []),
	?_assert(true).
