-module(eepaxos_process_commit_request_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[{"", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun commit_request_basic/1}}
	, {"", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun commit_request_dup/1}}
	].

commit_request_basic(Pid) -> ?_assert(true).

commit_request_dup(Pid) -> ?_assert(true).
