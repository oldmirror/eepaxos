-module(eepaxos_process_commit_request_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[{"commit_request_basic", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun commit_request_basic/1}}
	, {"commit_request_dup", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun commit_request_dup/1}}
	].

commit_request_basic(Pid) ->
	io:format(user, "commit_request_basic", []),
	?_assert(true).

commit_request_dup(Pid) ->
	io:format(user, "commit_request_dup", []),
	?_assert(true).
