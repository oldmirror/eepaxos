-module(eepaxos_executor_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[{"Basic"
			, {setup, fun start/0, fun stop/1
			, fun basic_test/1}}
	, {"Basic2"
			, {setup, fun start/0, fun stop/1
			, fun basic2_test/1}}
	, {"Basic3"
			, {setup, fun start/0, fun stop/1
			, fun basic3_test/1}}
	].

start() -> 
	ets:new(inst, [set, public, named_table, {keypos, #inst.key}]),
ok.

stop(PID) ->
	ets:delete(inst).

basic_test(Pid) -> 
	%create graph
	ets:insert(inst, #inst{key={1, 1}, deps=[], seq = 1}),

	eepaxos_execute_process:execute({1, 1}),
	?_assert(true).

basic2_test(Pid) ->
	%create graph
	ets:insert(inst, #inst{key = {1, 1}, deps = [{2,1}], seq = 1}),
	%ets:insert(inst, #inst{key = {2, 1}, deps = [{1,1}], seq = 2}),

	eepaxos_execute_process:execute({1, 1}),
	?_assert(true).

basic3_test(Pid) ->
	ets:insert(inst, #inst{key = {1, 1}, deps = [], seq = 1}),
%	ets:insert(inst, #inst{key = {1, 2}, deps = [{1,1}], seq = 2}),
%	ets:insert(inst, #inst{key = {1, 3}, deps = [{1,2}], seq = 3}),
%	ets:insert(inst, #inst{key = {0, 4}, deps = [{1,3}], seq = 4}),

	eepaxos_execute_process:execute({1, 1}),
	?_assert(true).
