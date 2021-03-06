-module(eepaxos_membership).
-behavior(gen_server).
-export([join/1, remove/1]).

-export([code_change/3,
		handle_info/2,
		terminate/2,
		handle_call/3,
		handle_cast/2]).

-record(state, {members = []
				, alive_members = []
				, order_map = []
				, available_nodes = []
				, quorum_num = 1
				, fast_quorum_num = 1
				, partitionId
				}).

% bare minimum implementation
% dynamic reconfiguration should be added

start(PartitionId) ->
	gen_server:start(PartitionId, ?MODULE, [PartitionId], []).
	
join(Node) when is_atom(Node)-> 
	ok = gen_server:call(?MODULE, {join, Node}).

remove(Node) ->
	ok = gen_server:call(?MODULE, {remove, Node}).

init([PartitionId, Members]) ->
	State = #state{partitionId = PartitionId, members = Members},
	{ok, State}.

handle_call({join, Node}, From,  State) ->
	State1 = State#state{alive_members = State#state.alive_members ++ Node},
	{reply, ok, State1};
handle_call({join, Node}, From, State) ->
	State1 = State#state{alive_members = State#state.alive_members - Node},
	{reply, ok, State1}.

code_change(_OldVsn, _State, _Extra) -> ok.
handle_info(_Info, _State) -> ok.
handle_cast(_, State) -> ok.
terminate(_Reason, _State) -> ok.

