-module(eepaxos_process_commit_request_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[{"commit_request_basic. No record", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun commit_request_basic/1}}
	, {"commit_request_dup. Must be ignored", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun commit_request_dup/1}}
	].

commit_request_basic(Pid) ->
	io:format(user, "FUNCTION_LABEL: commit_request_basic", []),
	timer:sleep(3000),
	?_assert(true).

commit_request_over_prepare(Pid) ->
	io:format(user, "FUNCTION_LABEL: commit_request_over_prepare", []),
	timer:sleep(3000),
	?_assert(true).

commit_request_over_accepted(Pid) ->
	io:format(user, "FUNCTION_LABEL: commit_request_over_accepted", []),
	timer:sleep(3000),
	?_assert(true).

commit_request_dup(Pid) ->
	io:format(user, "FUNCTION_LABEL: commit_request_dup", []),
	timer:sleep(3000),
	?_assert(true).
