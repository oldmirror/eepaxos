-module(eepaxos_process_accept_response_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eepaxos_types.hrl").

run_test_() ->
	[{"basic case", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun accept_response_nochange/1}}
	, {"", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun accept_response_change/1}}
	, {"accept requested after prepare", {setup, fun process_testing_util:start/0, fun process_testing_util:stop/1, fun accept_by_other_leader/1}}
	].

accept_response_all_resp(Pid) ->
	%%%================================
	%%% set node state 
	%%%
	%%% command: set(k, 1) 
	%%% deps: []
	%%% seq: 1
	%%%================================
	Cmd = #eepaxos_command{operation = set, key = k, value = 1},
	Inst = #inst{key = {1, 1}
			, ballot = {0, 0, 0}
			, cmd  = Cmd
			, deps = []
			, seq = 1
			, state = accepted},
		
	Lbk = #lbk{key = {1, 1}
			,prepareoks = 0
			,allequal = true
			,preacceptoks = 0
			,acceptoks = 1
			,nacks = 0
			,originaldeps
			,committeddeps
			,preparing = false
			,clientProposals  
			}).

	ets:insert(inst, Inst),
	ets:insert(lbk, Lbk),

	eepaxos_process:accept_response(Pid, #accept_response{ inst_key = {1, 1}),


	 ?_assert(true).


accept_response_nack(Pid) -> ?_assert(true).

accept_response_ignore_additional(Pid) -> ?_assert(true).

accept_by_other_leader(Pid) ->
	%%%================================
	%%% set node state 
	%%%
	%%% command: set(k, 1) 
	%%% deps: []
	%%% seq: 1
	%%%================================
	
?_assert(true).
