-module(basic_test_SUITE).
-include_lib("common_test/include/ct.hrl").
-export([all/0]).
-export([test_tester/1]).

all() ->
	[test_tester].
	
init_per_testcase(test_tester, Config) ->
	ets:new(temp, [set, named_table]),
	Config.

test_tester(_Config) ->
	F = fun() ->
		Fun  = fun(A) ->
			receive
				{Pid, Msg} ->
					error_logger:info_msg("~w, ~w~n", [Pid, Msg]),
					Pid ! ok;
				_ -> 
					error_logger:info_msg("some other"),
					self() ! no
			end,
			A(A)
		end,
		Fun(Fun)
	end,
	register(tester, spawn(F)).
