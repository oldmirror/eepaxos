-module(eepaxos_process_prepare_request_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[{"", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun prepare_request_nochange/1}}
	, {"", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun prepare_request_change/1}}
	].

prepare_request_nochange(Pid) -> ?_assert(true).

prepare_request_change(Pid) -> ?_assert(true).