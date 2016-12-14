-module(eepaxos_process).
-behavior(gen_server).
-include("../include/eepaxos_types.hrl").
-export([code_change/3,
	handle_info/2,
	terminate/2]).

-define(debug, false).
-define(TESTER, {tester, 'tester@Sungkyus-MacBook-Pro-2.local'}).

-ifdef(debug).
-define(TEST_CALL(Param), ?TESTER ! Param, receive Msg -> ok end).
-else.
-define(TEST_CALL(Param), noop).
-endif.

-export([start_link/0, init/1, 
		propose/2,
		preaccept/6,
		preaccept_handle/6,
		paxos_accept_request/6,
		paxos_accept_response/5,
		handle_call/3,
		handle_cast/2, 
		runCommit/2,
		runAccept/2,
		commit_request/5,
		make_call/5]).

-record(state, {instNo =0, % instance number
				replicaId = -1, %replica ID
				replicas = [], 
				numToSend = 0 :: integer(),
				totalReplicaNo = 1 :: integer(),
				epoch = 0}).
-type state() :: preaccepted | accepted | commited | executed.

-record(inst, {key
		, ballot :: ballot_num()
		, cmd  = #eepaxos_command{}
		, deps = []
		, seq = -1
		, state = undefined :: state()
		}).
	
-record(lbk, {key
		,maxrecvballot
		,prepareoks = 0 ::integer()
		,allequal
		,preacceptoks = 0 ::integer()
		,acceptoks = 0 ::integer()
		,nacks = 0
		,originaldeps
		,committeddeps
		,recoveryinst
		,preparing
		,tryingtopreaccept
		,possiblequorum
		}).

start_link() ->
	error_logger:info_msg("start_link"),
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> 
	error_logger:info_msg("init"),
	ets:new(inst, [ordered_set, named_table, {keypos, #inst.key}, public, {write_concurrency, true}, {read_concurrency, true}]),
	ets:new(lbk, [ordered_set, named_table, {keypos, #lbk.key}, public, {write_concurrency, true}, {read_concurrency, true}]),


	ets:new(maxSeqPerKey, [ordered_set, named_table]),
	Replicas = ['b@Sungkyus-MacBook-Pro-2.local', 'a@Sungkyus-MacBook-Pro-2.local', 'c@Sungkyus-MacBook-Pro-2.local'],
	NoFQuorum = trunc(length(Replicas)/2),
	
	lists:foreach(fun(NodeName) ->
		put(list_to_atom("conf_" ++ atom_to_list(NodeName)), [])
	end, Replicas),

	 {ok, #state{
		instNo = 0, 
		replicaId = 0,
		replicas = Replicas,
		numToSend = NoFQuorum
		}}. 

% local call made by client. Returns after 
-spec propose(atom(), atom()) -> ok | {error, invalid_param}.
propose(Pid, Command) when record(Command, eepaxos_command) ->
	%Key = Command#eepaxos_command.key
	error_logger:info_msg("process:proposed~n"),
	gen_server:call(?MODULE, {propose, Command});
propose(Pid, Command) -> {error, invalid_param}.

commit_request(ReplicaId, InstNo, Command, Deps, Seq) ->
	error_logger:info_msg("process:commit_reqest~n"),
	gen_server:cast(?MODULE, {commit_request, ReplicaId, InstNo, Command, Deps, Seq}).

preaccept(Ballot, ReplicaId, InstNo, Command, Deps, Seq) ->
	error_logger:info_msg("process:preaccept_request~n"),
	gen_server:cast(?MODULE, {preaccept, Ballot, ReplicaId, InstNo, Command, Deps, Seq}).

preaccept_handle(ReplicaId, InstNo, Command, Deps, Seq, Changed) ->
	error_logger:info_msg("process:preaccept_response~n"),
	gen_server:cast(?MODULE, {preaccept_handle, ReplicaId, InstNo, Command, Deps, Seq, Changed}).

paxos_accept_request(Ballot, ReplicaId, InstNo, Command, Deps, Seq) ->
	error_logger:info_msg("process:paxos_accept_request called~n"),
	gen_server:cast(?MODULE, {paxos_accept_request, Ballot,  ReplicaId, InstNo, Command, Deps, Seq}).

paxos_accept_response(ReplicaId, InstNo, Command, Deps, Seq) ->
	error_logger:info_msg("process:paxos_accept_response called~n"),
	gen_server:cast(?MODULE, {paxos_accept_response, ReplicaId, InstNo, Command, Deps, Seq}).

start_prepare(Command) when record(Command, eepaxos_command) ->
	error_logger:info_msg("process:start_prepare~n"),
	gen_server:cast(?MODULE, {start_prepare, Command}).

explicit_prepare_request(Ballot, ReplicaId, InstNo, Command, Deps, Seq) ->
	error_logger:info_msg("process:paxos_accept_response called~n"),
	gen_server:cast(?MODULE, {explicit_prepare_request, Ballot, ReplicaId, InstNo, Command, Deps, Seq}).

explicit_prepare_response(ReplicaId, InstNo, Command, Deps, Seq) ->
	error_logger:info_msg("process:paxos_accept_response called~n"),
	gen_server:cast(?MODULE, {explicit_prepare_response, ReplicaId, InstNo, Command, Deps, Seq}).

try_preaccept(ReplicaId, InstNo, Command, Deps, Seq) ->
	error_logger:info_msg("process:paxos_accept_response called~n"),
	gen_server:cast(?MODULE, {explicit_prepare_response, ReplicaId, InstNo, Command, Deps, Seq}).

handle_call({propose, Command}, From, State) ->
	error_logger:info_msg("leader executes handle_call(propose)~n"),
	%propose. Construct the record with depts and seq
	InstNo = State#state.instNo + 1,

	%find depedencies
	Deps = lists:foldl(fun(ReplicaId, Accum) -> 
		KeyName = list_to_atom("conf_" ++ atom_to_list(ReplicaId)),
		Conflicts = get(KeyName),
		case lists:keyfind(Command#eepaxos_command.key, 1, Conflicts) of
			false -> [{ReplicaId, -1} | Accum];
			{_, InstNoConf} -> [{ReplicaId, InstNoConf} | Accum]
		end
	end, [], State#state.replicas),

	%get seq
	Seq = case ets:lookup(maxSeqPerKey, Command#eepaxos_command.key) of
		[]  -> 1;
		[{K, MaxSeq} | _T]  -> MaxSeq + 1
	end,

	ets:insert(maxSeqPerKey, {Command#eepaxos_command.key, Seq}), %insertion updates the record
	
	Ballot = {State#state.epoch, 0, node()},
	ets:insert(inst, #inst{
		ballot = Ballot
		,key = {node(), InstNo}
		, cmd  = Command
		, deps = Deps
		, seq = Seq
		, state = preaccepted}),

	ets:insert(lbk, #lbk{key = {node(), InstNo}
%		,maxrecvballot = 
		,allequal = true
%		,originaldeps
%		,committeddeps
%		,recoveryinst
%		,preparing
%		,tryingtopreaccept
%		,possiblequorum
		}),

	ConfName = list_to_atom("conf_" ++ atom_to_list(node())),
	ConfForR = get(ConfName),

	case lists:keyfind(Command#eepaxos_command.key, 1, ConfForR) of
		false -> put(ConfName, [{Command#eepaxos_command.key, InstNo} | ConfForR]);
		_ -> put(ConfName, lists:keyreplace(Command#eepaxos_command.key, 1, ConfForR, {Command#eepaxos_command.key, InstNo}))
	end,
	
	ListToSend = lists:subtract(State#state.replicas, [node()]),
	NumToSend =  State#state.numToSend,
	error_logger:info_msg("preaccept_request send to ~w of ~w~n", [NumToSend, ListToSend]),
	Ok = make_call(ListToSend, NumToSend, eepaxos_process, preaccept, [Ballot, node(), InstNo, Command, Deps, Seq]),
	error_logger:info_msg("finishing handle_call(propose)"),

	{reply, Ok, State#state{instNo = InstNo}}.
%==================================================================
%	preaccept
%==================================================================
handle_cast({preaccept, Ballot, ReplicaId, InstNo, Command, Deps, Seq}, State) -> %acceptor handler
%	?TEST_CALL({{self(), node()}, {preaccept, Command}}),
	error_logger:info_msg("Acceptor(~w) executes handle_cast(preaccept_request)~n", [node()]),
	Updated = make_ref(),
	put(Updated, false),
	% update attributes
	Deps1 = lists:foldl(fun(DepElem, Accum) -> 
		{FoldingReplicaId, FoldingInstNo} = DepElem,
		Conflicts = get(list_to_atom("conf_" ++ atom_to_list(FoldingReplicaId))),
		case lists:keyfind(Command#eepaxos_command.key, 1, Conflicts) of
			false -> [DepElem | Accum];
			{_, InstNoConf} -> 
				if 
					InstNoConf > FoldingInstNo -> 
						put(Updated, true),
						[{FoldingReplicaId, InstNoConf} | Accum];
					true ->
						[DepElem | Accum]
				end
		end
	end, [], Deps),

	SeqNew = case ets:lookup(maxSeqPerKey, Command#eepaxos_command.key) of
		[] -> Seq;
		[{_, MaxSeq} | _T] -> 
			SeqNewCandid = MaxSeq + 1,
			if 
				SeqNewCandid > Seq -> 
					put(Updated, true),
					SeqNewCandid;
				true -> Seq
			end
	end,

	% update local data
	ets:insert(inst, #inst{
		ballot = Ballot
		,key = {ReplicaId, InstNo}
		, cmd  = Command
		, deps = Deps
		, seq = SeqNew
		, state = preaccepted}),
	
	ets:insert(maxSeqPerKey, {Command#eepaxos_command.key, SeqNew}),

	ConfName = list_to_atom("conf_" ++ atom_to_list(ReplicaId)),
	ConfForR = get(ConfName),

	case lists:keyfind(Command#eepaxos_command.key, 1, ConfForR) of
		false -> put(ConfName, [{Command#eepaxos_command.key, InstNo} | ConfForR]);
		_ -> put(ConfName, lists:keyreplace(Command#eepaxos_command.key, 1, ConfForR, {Command#eepaxos_command.key, InstNo}))
	end,

	Change = 
	case get(Updated) of
		false ->
			Command1 = Deps2 = Seq1 = undefined,  % set undefined for efficiency
			no_change;
		true -> 
			Command1 = Command,
			Deps2 = Deps1,
			Seq1 = SeqNew,
			changed
	end,
	erase(Updated),

	rpc:call(ReplicaId, eepaxos_process, preaccept_handle, [ReplicaId, InstNo, Command1, Deps2, Seq1, Change]),
	error_logger:info_msg("finishing handle_cast(preaccept_request) - ~w ~w ~w ~w ~w ~w", [ReplicaId, InstNo, Command1, Deps2, Seq1, Change]),
	{noreply, State};

handle_cast({preaccept_handle, ReplicaId, InstNo, Command, Deps, Seq, ChangeState}, State) -> %acceptor handler
	error_logger:info_msg("leader executes handle_cast(preaccept_response)"),
	
	PokNo = ets:lookup_element(lbk, {ReplicaId, InstNo}, #lbk.preacceptoks) + 1,
	ets:update_element(lbk, {ReplicaId, InstNo}, {#lbk.preacceptoks, PokNo}),
%TODO: handle the case in which instance has moved away from preaccept phase. It's possible that quorum of node already preaccepted

	case ChangeState of 
		no_change -> % acceptor returned OK. Only increment accept value. 
			error_logger:info_msg("no_change received~n");
		changed -> % if change found, update deps and seq
			error_logger:info_msg("changed received~n"),
			A = ets:lookup(inst, {ReplicaId, InstNo}),
			[#inst{deps = DepsOrigin, seq = SeqOrigin, state = St} | _T]= A,

			%merge deps
			DepsResult = lists:foldr(fun({ReplicaIdOrigin, InstNoOrigin} = DOrigin, Accum) ->
				{_, InstNoIn} = lists:keyfind(ReplicaIdOrigin, 1, Deps),
				if
					InstNoIn > InstNoOrigin -> [{ReplicaIdOrigin, InstNoIn} | Accum];
					true -> [{ReplicaIdOrigin, InstNoOrigin} | Accum]
				end
			end, [], DepsOrigin),
			%merge seq
			SeqResult = if SeqOrigin > Seq -> SeqOrigin; true -> Seq end,
	
			ets:insert(inst, #inst{key = {ReplicaId, InstNo}
											, cmd  = Command
											, deps = DepsResult
											, seq = SeqResult
											, state = St}),
			ets:update_element(lbk, {ReplicaId, InstNo}, {#lbk.allequal, false}),
			error_logger:info_msg("updated local instance record with the change~n");
			
		_ -> error_logger:info_msg("error condition~n")
	end,
	
	[#inst{cmd=CommandNew
		, deps=DepsNew
		, seq = SeqNew} | _T1] = ets:lookup(inst, {ReplicaId, InstNo}),

	 % if more than certain number of nodes preaccepted, move on to commit
	if PokNo >= (State#state.numToSend) -> %TODO: how to manage quorum
			AllEqual = ets:lookup_element(lbk, {ReplicaId, InstNo}, #lbk.allequal),
			if AllEqual -> % fast_path
					error_logger:info_msg("Starting commit~n"),
					runCommit({State, ReplicaId, InstNo, CommandNew, DepsNew, SeqNew}, State);
				% slow path
				true -> 
					error_logger:info_msg("Starting phase2(paxos accept)~n"),
					runAccept({ReplicaId, InstNo, CommandNew, DepsNew, SeqNew}, State)
			end;
		true -> error_logger:info_msg("just increment preaccept oks. PokNo = ~w", [PokNo])
	end,
	error_logger:info_msg("finishing handle_cast(preaccept_response).~n"),
	{noreply, State};

handle_cast({paxos_accept_request, Ballot, ReplicaId, InstNo, Command, Deps, Seq}, State) -> 
	error_logger:info_msg("acceptor(~w) executes handle_cast(paxos_accept_request)~n", [node()]),
	AcceptedInst = ets:lookup(inst, {ReplicaId, InstNo}),
	
	if 
		is_record(AcceptedInst, inst) andalso Ballot >  AcceptedInst#inst.ballot -> 
 % it hasn't seen any request larger than this ballot
			ets:insert(inst, #inst{key = {ReplicaId, InstNo}
											, cmd  = Command
											, deps = Deps
											, seq = Seq 
											, state = accepted}),
			make_call([ReplicaId], 1, eepaxos_process, paxos_accept_response, [ReplicaId, InstNo, Command, Deps, Seq]);
		true -> % not newer. As in paxos algorithm, reply with NACK 
			make_call([ReplicaId], 1, eepaxos_process, paxos_accept_response, [ReplicaId, InstNo, nack, undefined, undefined])
	end, 
	error_logger:info_msg("finishing handle_cast(paxos_accept_request).~n"),
	{noreply, State};

handle_cast({paxos_accept_response, ReplicaId, InstNo, Command, Deps, Seq}, State) -> 
	error_logger:info_msg("leader handle_cast(paxos_accept_response)~n"),
	Inst = ets:lookup(inst, {ReplicaId, InstNo}), 
	if Inst#inst.state > accepted -> % finished processing
			{noreply, State};
		true -> 
			if Command =:= nack -> % acceptor prepared or accepted for higher ballot
					{noreply, State};
				true ->
					I = ets:lookup_element(lbk, {ReplicaId, InstNo}, #lbk.acceptoks) + 1,
					ets:update_element(lbk, {ReplicaId, InstNo}, {#lbk.acceptoks, I}),
					
					State2  = if 
						I >= State#state.numToSend -> 
							runCommit({State, ReplicaId, InstNo, Command, Deps, Seq}, State);
						true -> State
					end,
					error_logger:info_msg("finishing handle_cast(paxos_accept_response)~n"),
					{noreply, State2}
			end
	end;

handle_cast({commit_request, ReplicaId, InstNo, Command, Deps, Seq}, State) ->
	error_logger:info_msg("acceptor (~w) commit_request - ~w ~w ~w ~w ~w~n", [node(), ReplicaId, InstNo, Command, Deps, Seq]),
	%update instance with commited state. protocol ends
	ets:update_element(inst, {ReplicaId, InstNo}, {#inst.state, commited}),
	{noreply, State};

handle_cast({start_explicit_prepare, Ballot, ReplicaId, InstNo, Command, Deps, Seq}, State) ->
	% this node is potentially new command leader for the instance. 
	error_logger:info_msg("new leader(~w) start_explicit_prepare- ~w ~w ~w ~w ~w~n", [node(), ReplicaId, InstNo, Command, Deps, Seq]),
	% safe to assume it is not commited
	
	Inst = ets:lookup(inst, {ReplicaId, InstNo}),
	#inst{ballot = {E, S, _}, state = St} = Inst,
	case St of
		commited -> ok;
		accepted -> ok
	end

	ets:insert(inst, #lbk{}),

	Ballot = {E, S+1, node()},
	
	make_call(lists:subtract(State#state.replicas, [node()]), State#state.numToSend, eepaxos_process,
				explicit_prepare_request, [Ballot, LeaderReplica, ReplicaId, InstNo, Command, Deps, Seq]),
	{noreply, State};
handle_cast({explicit_prepare_request, Ballot, LeaderReplica, ReplicaId, InstNo, Command, Deps, Seq}, State) ->
	error_logger:info_msg("acceptor (~w) explicit_prepare_request- ~w ~w ~w ~w ~w~n", [node(), ReplicaId, InstNo, Command, Deps, Seq]),
	% Handle prepare request as in paxos
	Inst = ets:lookup(inst, {ReplicaId, InstNo}),
	
	if 
		is_record(Inst, inst) andalso Ballot >  Inst#inst.ballot -> %is_record means it is not false, meaning record exists
			ets:insert(inst, #inst{key = {ReplicaId, InstNo}
											, cmd  = Command
											, deps = Deps
											, seq = Seq 
											, state = prepared}),
			make_call([LeaderReplica], 1, eepaxos_process, explicit_prepare_response, 
				[ReplicaId, InstNo, Command, Deps, Seq, Inst#inst.state]);
		true -> % not newer. As in paxos algorithm, reply with NACK 
			make_call([LeaderReplica], 1, eepaxos_process, explicit_prepare_response, [ReplicaId, InstNo, nack, undefined, undefined, undefined])
	end, 
	error_logger:info_msg("finishing handle_cast(explicit_prepare_request).~n"),
	{noreply, State};
handle_cast({explicit_prepare_response, ReplicaId, InstNo, Command, Deps, Seq, PrevState}, State) ->
	error_logger:info_msg("acceptor (~w) explicit_prepare_response- ~w ~w ~w ~w ~w~n", [node(), ReplicaId, InstNo, Command, Deps, Seq]),
	Inst = ets:lookup(inst, {ReplicaId, InstNo}),
	Lbk = ets:lookup(lbk, {ReplicaId, InstNo}),
	if Inst#inst.state > commited or Inst#inst.state > accepted -> % moved on
		{noreply, State};
		true ->
		
			case  PrevState of
				% if any commited node exist, send commit
				commited -> 
					ets:update_element(inst, {ReplicaId, InstNo}, {#inst.state, commited}),
					runCommit(State);
				accepted ->
					ets:update_element(inst, {ReplicaId, InstNo}, {#inst.state, accepted}),
					runAccept(State)
			end,
			PrepOks = Lbk#lbk.prepareoks + 1,
			
			if PrepOks > 
			
			
			
			ets:update_element(inst, {ReplicaId, InstNo}, {#inst.state, commited}),
			{noreply, State}
	end;
handle_cast({try_preaccept_request, ReplicaId, InstNo, Command, Deps, Seq}, State) ->
	error_logger:info_msg("acceptor (~w) try_preaccept_request- ~w ~w ~w ~w ~w~n", [node(), ReplicaId, InstNo, Command, Deps, Seq]),
	%update instance with commited state. protocol ends
	ets:update_element(inst, {ReplicaId, InstNo}, {#inst.state, commited}),
	{noreply, State}.

%start accept phase
runAccept({LeaderId, ReplicaId, InstNo, Command, Deps, Seq}, State) ->
	error_logger:info_msg("leader executes process:runAccept~n"),
	ets:update_element(inst, {ReplicaId, InstNo}, {#inst.state, accepted}),
	ets:update_element(lbk, {ReplicaId, InstNo}, {#lbk.acceptoks, 1}),
	%rpc:multicall(State#state.replicas, eepaxos_process, paxos_accept_request, [ReplicaId, InstNo, Command, Deps, Seq]).
	make_call(lists:subtract(State#state.replicas, [node()]), State#state.numToSend, eepaxos_process, paxos_accept_request, [ReplicaId, InstNo, Command, Deps, Seq]),
	error_logger:info_msg("finishing executes process:runAccept~n").

%start commit phase
runCommit({State, ReplicaId, InstNo, Command, Deps, Seq}, State) ->
	DBUpdated = ets:update_element(inst, {ReplicaId, InstNo}, {#inst.state, commited}),
	error_logger:info_msg("~w", [ets:lookup(inst, {ReplicaId, InstNo})]),
	%TODO: notify client 
	
	
	%Broadcast
	% no need to send to local instance since already updated
	%rpc:multicall(State#state.replicas, eepaxos_process, commit_request, [ReplicaId, InstNo, Command, Deps, Seq]),
	make_call(lists:subtract(State#state.replicas, [node()]), length(State#state.replicas)-1, eepaxos_process, commit_request, [ReplicaId, InstNo, Command, Deps, Seq]),
	State.


code_change(_OldVsn, _State, _Extra) -> ok.
handle_info(_Info, _State) -> ok.
terminate(_Reason, _State) -> ok.

make_call(NodeList, Num, Module, Fun, Args) ->
	try lists:foldr(
			fun(_, 0) -> 
				throw(all_sent);
				(Node, Cnt) ->
					Result = rpc:call(Node, Module, Fun, Args),
					if 
						ok =:= Result -> 
							error_logger:info_msg("debug ~w~n", [Cnt]),
							Cnt-1;
						true -> Cnt	
					end
			 end, Num, NodeList) of
		Num when Num > 0 -> {error, fail_to_send_quorum};
		_ -> ok
	catch
		all_sent ->
			ok;
		_ -> {error, unknown_failure}
	end.
