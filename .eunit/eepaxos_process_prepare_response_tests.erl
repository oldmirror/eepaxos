-module(eepaxos_process_prepare_response_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[{"prepare_reponse_nochange", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun prepare_response_nochange/1}}
	, {"prepare_response_change", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun prepare_response_change/1}}
	].

prepare_response_nochange(Pid) ->
	io:format(user, "prepare_response_nochange~n", []),
	?_assert(true).

prepare_response_change(Pid) ->
	io:format(user, "prepare_response_change~n", []),
	?_assert(true).
