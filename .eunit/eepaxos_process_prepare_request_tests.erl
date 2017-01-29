-module(eepaxos_process_prepare_request_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[{"prepare_request", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun prepare_request_nochange/1}}
	, {"preaccept_request", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun prepare_request_change/1}}
	].

prepare_request_nochange(Pid) ->
	io:format(user, "prepare_request_nochange~n", []),
	?_assert(true).

prepare_request_change(Pid) ->
	io:format(user, "prepare_request_change~n", []),
	?_assert(true).
