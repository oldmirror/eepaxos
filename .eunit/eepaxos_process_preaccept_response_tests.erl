-module(eepaxos_process_preaccept_response_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[{"preaccept_response_nochange", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun preaccept_response_nochange/1}}
	, {"preaccept_response_change", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun preaccept_response_change/1}}
	].

preaccept_response_nochange(Pid) ->
	io:format(user, "preaccept_request_nochange~n", []),
	?_assert(true).

preaccept_response_change(Pid) ->
	io:format(user, "preaccept_response_change~n", []),
	?_assert(true).
