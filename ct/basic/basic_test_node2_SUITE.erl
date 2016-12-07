-module(basic_test_node2_SUITE).
-include_lib("common_test/include/ct.hrl").
-export([all/0]).
-export([test_node2/1, init_per_testcase/2]).
-record(eepaxos_command, {operation, key, value}).

all() ->
	[test_node2].
	
init_per_testcase(test_node2, Config) ->
	application:stop(eepaxos),
	OK = application:start(eepaxos),
	timer:sleep(1000),
	error_logger:info_msg("application started - ~n ~n", [OK]),
	Config.

test_node2(_Config) ->
	application:start(eepaxos),
	eepaxos_process:propose(self(), #eepaxos_command{operation=set, key = k, value=2}).
