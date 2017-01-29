-module(eepaxos_membership_mock).
-behavior(gen_server).

-export([code_change/3,
		handle_info/2,
		init/1,
		start_link/2,
		terminate/2,
		handle_call/3,
		handle_cast/2]).

-record(state, {members = []
				, alive_members = []
				, order_map = []
				, quorum_num = 1
				, fast_quorum_num = 1
				}).

%bare minimum implementation
%dynamic reconfiguration should be added
start_link(ServerName, Members) -> gen_server:start_link(ServerName, ?MODULE, [Members], []).

init([Members]) ->
	#state{members = Members}.
	

handle_call(_, _From, State) -> {reply, ok, State}.
handle_cast(_, State) -> {noreply, ok, State}.
handle_info(_Info, _State) -> ok.
code_change(_OldVsn, _State, _Extra) -> ok.
terminate(_Reason, _State) -> ok.
