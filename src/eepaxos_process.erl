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
		preaccept_request/1,
		preaccept_handle/1,
		paxos_accept_request/1,
		paxos_accept_response/1,
		handle_call/3,
		handle_cast/2, 
		do_preaccept_req/3, 
		do_preaccept_resp_merge/3,
		runCommit/3,
		runAccept/2,
		commit_request/1,
		make_call/5]).

-record(state, {instNo =0, % instance number
				replicaId = -1, %replica ID
				replicas = [], 
				numToSend = 0 :: integer(),
				totalReplicaNo = 1 :: integer(),
				epoch = 0}).
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

commit_request(CommitReq) ->
	error_logger:info_msg("process:commit_reqest~n"),
	gen_server:cast(?MODULE, {commit_request, CommitReq}).

preaccept_request(PAReq) when is_record(PAReq, preaccept_request) ->
	error_logger:info_msg("process:preaccept_request~n"),
	gen_server:cast(?MODULE, {preaccept_request, PAReq}).

preaccept_handle(PAResp) when is_record(PAResp, preaccept_response) ->
	error_logger:info_msg("process:preaccept_response~n"),
	gen_server:cast(?MODULE, {preaccept_handle, PAResp}).

paxos_accept_request(PAReq) when is_record(PAReq, accept_request) ->
	error_logger:info_msg("process:paxos_accept_request called~n"),
	gen_server:cast(?MODULE, {paxos_accept_request, PAReq}).

paxos_accept_response(PAResp) when is_record(PAResp, accept_response) ->
	error_logger:info_msg("process:paxos_accept_response called~n"),
	gen_server:cast(?MODULE, {paxos_accept_response, PAResp}).

start_prepare(InstKey) ->
	error_logger:info_msg("process:start_prepare~n"),
	gen_server:cast(?MODULE, {start_explicit_prepare, InstKey}).

explicit_prepare_request(EPReq) when is_record(EPReq, prepare_request) ->
	error_logger:info_msg("process:paxos_accept_response called~n"),
	gen_server:cast(?MODULE, {explicit_prepare_request, EPReq}).

explicit_prepare_response(EPResp) when is_record(EPResp, prepare_response)  ->
	error_logger:info_msg("process:paxos_accept_response called~n"),
	gen_server:cast(?MODULE, {explicit_prepare_response, EPResp}).

try_preaccept(ReplicaId, InstNo, Command, Deps, Seq) ->
	error_logger:info_msg("process:paxos_accept_response called~n"),
	gen_server:cast(?MODULE, {explicit_prepare_response, ReplicaId, InstNo, Command, Deps, Seq}).

handle_call(_, From, State) -> {reply, reply, State}.

handle_cast({propose, Command}, State) ->
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
		, allequal = true
%		,originaldeps
%		,committeddeps
		, preparing = false
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
	Ok = make_call(ListToSend, NumToSend, eepaxos_process, preaccept_request, 
			[Ballot, node(), InstNo, Command, Deps, Seq]
				),
	error_logger:info_msg("finishing handle_call(propose)"),

	{noreply, State#state{instNo = InstNo}};
%==================================================================
%	preaccept
% ==================================================================
handle_cast({preaccept_request, PAReq}, State) -> %acceptor handler
	error_logger:info_msg("Acceptor(~w) executes handle_cast(preaccept_request)~n", [node()]),
	Inst = ets:lookup(inst, PAReq#prepare_request.inst_key),
	% if inst exists, it's probably late
	if Inst =/= false andalso Inst#inst.ballot >= PAReq#preaccept_request.ballot -> % already accepted higher ballot
			{noreply, State};
		Inst =/= false andalso Inst#inst.state >= accepted ->  
			% voting has been completed. it does nothing rather rather than starting new paxos since it's on instance.
			%TODO handle reordered acceptted/committed
			{noreply, State};
		true -> 		
			State1 = do_preaccept_req(State, PAReq, Inst), % update deps and seq. update local tables. make response.
			{noreply, State1}
	end;

handle_cast({preaccept_handle, PARes}, State) ->
	error_logger:info_msg("leader executes handle_cast(preaccept_response)"),
	[Inst | _T] = ets:lookup(inst, PARes#prepare_response.inst_key),

	if Inst#inst.state > preaccept -> %instance might have met quorum requirement and moved on
			{noreply, State};
		true ->
			PokNo = ets:lookup_element(lbk, PARes#preaccept_response.inst_key, #lbk.preacceptoks) + 1,
			ets:update_element(lbk, PARes#preaccept_response.inst_key, {#lbk.preacceptoks, PokNo}),

			{State1, InstNew} = do_preaccept_resp_merge(State, PARes, Inst),
			Lbk = ets:lookup(lbk, InstNew#inst.key),
		
			% quorum responded. move on 
			case PokNo >= (State#state.numToSend) of 
				true -> %TODO: how to manage quorum
					AllEqual = Lbk#lbk.allequal,
					if AllEqual -> % fast_path
							error_logger:info_msg("Starting commit~n"),
							runCommit(InstNew, Lbk, State);
						true -> % slow path
							error_logger:info_msg("Starting phase2(paxos accept)~n"),
							runAccept({ element(1, PARes#preaccept_response.inst_key), element(2, PARes#preaccept_response.inst_key),  InstNew#inst.cmd, InstNew#inst.deps, InstNew#inst.seq}, State)
					end
			end,
			error_logger:info_msg("finishing handle_cast(preaccept_response).~n"),
			{noreply, State1}
	end;

handle_cast({paxos_accept_request, AcceptReq}, State) -> 
	error_logger:info_msg("acceptor(~w) executes handle_cast(paxos_accept_request)~n", [node()]),
	Inst = ets:lookup(inst, AcceptReq#accept_request.inst_key),
	if Inst =/= false andalso Inst#inst.ballot > AcceptReq#accept_request.ballot -> % new leader is handling this
			{noreply, State};
		Inst =/= false andalso Inst#inst.state >= accepted -> % voting has been completed. TODO: CMU Go impl checks committed and executed only.
			{noreply, State};
		true -> 
			ets:insert(inst, #inst{key = AcceptReq#accept_request.inst_key
						, ballot = AcceptReq#accept_request.ballot
						, cmd  = AcceptReq#accept_request.cmd
						, deps = AcceptReq#accept_request.deps
						, seq = AcceptReq#accept_request.seq 
						, state = accepted}),
			make_call([AcceptReq#accept_request.leader]
				, 1, eepaxos_process, paxos_accept_response
				, [#accept_response{inst_key = AcceptReq#accept_request.inst_key
%									, cmd = AcceptedReq#accept_request.cmd
%									, deps = AcceptedReq#accept_request.deps
%									, seq = AcceptedReq#accept_request.seq
}]),
			error_logger:info_msg("finishing handle_cast(paxos_accept_request).~n"),
			{noreply, State}
	end;

handle_cast({paxos_accept_response, AcceptResp}, State) -> 
	error_logger:info_msg("leader handle_cast(paxos_accept_response)~n"),
	Inst = ets:lookup(inst, AcceptResp#accept_response.inst_key), 
	if Inst#inst.state > accepted -> % finished processing
			{noreply, State};
		true -> 
			I = ets:lookup_element(lbk, AcceptResp#accept_request.inst_key, #lbk.acceptoks) + 1,
			ets:update_element(lbk, AcceptResp#accept_request.inst_key, {#lbk.acceptoks, I}),
			
			State2  = if 
				I >= State#state.numToSend -> 
					runCommit(Inst, ets:lookup(lbk, Inst#inst.key), State);
				true -> State
			end,
			error_logger:info_msg("finishing handle_cast(paxos_accept_response)~n"),
			{noreply, State2}
	end;

handle_cast({commit_request, CommitReq}, State) ->
	error_logger:info_msg("acceptor (~w) commit_request - ~w ~w ~w ~w ~w~n", [node(), CommitReq]),
	%update instance with commited state. protocol ends
	ets:insert(inst, CommitReq#commit_request.inst_key
				, #inst{ballot = CommitReq#commit_request.inst_key
					, cmd = CommitReq#commit_request.cmd
					, deps = CommitReq#commit_request.deps
					, seq = CommitReq#commit_request.seq
					, state= commited}),
	{noreply, State};

handle_cast({start_explicit_prepare, InstanceKey}, State) ->
	error_logger:info_msg("new leader(~w) start_explicit_prepare- ~w ~w ~w ~w ~w~n", [node(), InstanceKey]),
	
	Inst = ets:lookup(inst, InstanceKey),
	Inst1 = 
	if Inst =:= false ->
			ets:insert(inst, #inst{key=InstanceKey
							, ballot = {State#state.epoch, 1, node()} % no instance. ballot number 1
							, state = undetermined});
		true ->
			#inst{ballot = {E, S, _}, state = St} = Inst,
			NewBallot = {E, S+1, node()}, %TODO: should epoch be from previous record or current state?
			ets:update_element(inst, InstanceKey, {#inst.ballot, NewBallot}),
			Inst#inst{ballot = NewBallot}
	end,

	#inst{state = InstState} = Inst1,
	
	if InstState =:= committed -> %weird, but could happen
			runCommit(Inst1, ets:lookup(lbk, Inst1#inst.key), State),
			{noreply, State};
		true ->
			Lbk = #lbk{preparing=true},
			Lbk1 =
			case Inst1#inst.state of
				accepted -> 
					ets:insert(recoveryInst, #recoveryInst{key = Inst#inst.key
											, cmd = Inst#inst.cmd
											, deps = Inst#inst.deps
											, seq = Inst#inst.seq
											, hasOriginalResponded = false
											, preacceptCnt = 0});
				preaccepted ->
					ets:insert(recoveryInst, #recoveryInst{key = Inst#inst.key
											, cmd = Inst#inst.cmd
											, deps = Inst#inst.deps
											, seq = Inst#inst.seq
											, hasOriginalResponded = 
												if element(1, Inst1#inst.key) == node() -> true;
													 true -> false
												end,
											 preacceptCnt = 1})
			end,

			make_call(lists:subtract(State#state.replicas, [node()]), State#state.numToSend, eepaxos_process,
						explicit_prepare_request, [
							#prepare_request{ballot = Inst#inst.ballot, leader = node()
							, inst_key = Inst#inst.key
							}
						]),
			{noreply, State}
	end;

handle_cast({explicit_prepare_request, EPReq}, State) ->
	error_logger:info_msg("acceptor (~w) explicit_prepare_request- ~w ~w ~w ~w ~w~n", [node(), EPReq]),
	% Handle prepare request as in paxos
	Inst = ets:lookup(inst, EPReq#prepare_request.inst_key),
	
	if Inst =/= false andalso EPReq#prepare_request.ballot < Inst#inst.ballot ->
			{noreply, State};
		true -> 
			Inst1 = 
			case Inst of false ->
					#inst{key = EPReq#prepare_request.inst_key, ballot= EPReq#prepare_request.ballot, state=undetermined};
				_ -> 
					Inst#inst{ballot=EPReq#prepare_request.ballot}
			end,

			ets:insert(inst, Inst1),

			% respond with previous information
			make_call([EPReq#prepare_request.leader], 1, eepaxos_process, explicit_prepare_response, 
				[#prepare_response{inst_key = Inst1#inst.key
								, cmd = Inst1#inst.cmd
								, deps = Inst1#inst.deps
								, seq = Inst1#inst.seq
								, prev_status = Inst1#inst.state
								, is_original_leader =
									% compare replicaId and ballot
									if element(1,Inst1#inst.key) -> true;
										 true -> false
									end}]),
			error_logger:info_msg("finishing handle_cast(explicit_prepare_request).~n"),
			{noreply, State}
	end;

handle_cast({explicit_prepare_response, EPResp}, State) ->
	error_logger:info_msg("acceptor (~w) explicit_prepare_response- ~w ~w ~w ~w ~w~n", [node(), EPResp]),
	Inst = ets:lookup(inst, EPResp#prepare_response.inst_key),
	Lbk = ets:lookup(lbk, EPResp#prepare_response.inst_key),

	if Lbk#lbk.preparing =/= true -> % dropped
			{noreply, State};
		EPResp#prepare_response.prev_status >= committed ->
			runCommit(Inst, Lbk, State),
			ets:update_element(lbk, EPResp#prepare_response.inst_key, {#lbk.preparing, false}),
			{noreply, State};
		true ->
			PPedOk = Lbk#lbk.prepareoks + 1,
			ets:update_element(lbk, update),
			

			RecoveryInst = ets:lookup(recoveryInst, EPResp#prepare_response.inst_key),

			RecoveryInst1 =
			case RecoveryInst of
				false -> RecoveryInstTemp = #recoveryInst{};
				_ -> RecoveryInst
			end,

			if EPResp#prepare_response.prev_status =:= accepted ->
					RecoveryInstNew = #recoveryInst{key = EPResp#prepare_response.inst_key
										, cmd = EPResp#prepare_response.cmd
										, deps = EPResp#prepare_response.deps
										, seq = EPResp#prepare_response.seq
										, state = EPResp#prepare_response.prev_status},
					ets:insert(recoveryInst, EPResp#prepare_response.inst_key, RecoveryInstNew);

				EPResp#prepare_response.prev_status =:= preaccepted
					andalso  RecoveryInst1#recoveryInst.state =:= preaccepted -> % not sure if this condition is neccessary.
						RecoveryInst2 =
						 if RecoveryInst#recoveryInst.cmd =:= EPResp#prepare_response.cmd 
							andalso RecoveryInst#recoveryInst.deps =:= EPResp#prepare_response.deps %TODO: iterate
							andalso RecoveryInst#recoveryInst.seq =:= EPResp#prepare_response.seq -> %same as previous respond
								RecoveryInst1#recoveryInst{preacceptCnt = RecoveryInst1#recoveryInst.preacceptCnt + 1};
							true -> recoveryInst1 % preaccepted but not same.
						end,

						RecoveryInst3 =
						if EPResp#prepare_response.is_original_leader ->
							RecoveryInst1#recoveryInst{hasOriginalResponded = true};
							true -> RecoveryInst2
						end,
						
						ets:insert(recoveryInst, RecoveryInst3);
				true -> unknown_condition
			end,

			prepare_quorum_process(State, RecoveryInst, Lbk)
	end;

handle_cast({try_preaccept_request, ReplicaId, InstNo, Command, Deps, Seq}, State) ->
	error_logger:info_msg("acceptor (~w) try_preaccept_request- ~w ~w ~w ~w ~w~n", [node(), ReplicaId, InstNo, Command, Deps, Seq]),
	%update instance with commited state. protocol ends
	ets:update_element(inst, {ReplicaId, InstNo}, {#inst.state, commited}),
	{noreply, State};
handle_cast({try_preaccept_request, ReplicaId, InstNo, Command, Deps, Seq}, State) ->
	error_logger:info_msg("acceptor (~w) try_preaccept_request- ~w ~w ~w ~w ~w~n", [node(), ReplicaId, InstNo, Command, Deps, Seq]),
	%update instance with commited state. protocol ends
	ets:update_element(inst, {ReplicaId, InstNo}, {#inst.state, commited}),
	{noreply, State}.

%===================================
% Internal functions
%===================================
do_preaccept_req(State, PAReq, Inst) when Inst#inst.ballot >= PAReq#preaccept_request.ballot -> % old ballot
	State;
do_preaccept_req(State, PAReq, Inst) when Inst#inst.state > accepted ->
	State;
do_preaccept_req(State, PAReq, Inst) when is_record(State, state) andalso is_record(PAReq, preaccept_request) ->
	Updated = make_ref(),
	put(Updated, false),
	% update attributes
	Deps1 = lists:foldl(fun(DepElem, Accum) -> 
		{FoldingReplicaId, FoldingInstNo} = DepElem,
		Conflicts = get(list_to_atom("conf_" ++ atom_to_list(FoldingReplicaId))),
		case lists:keyfind(PAReq#preaccept_request.cmd#eepaxos_command.key, 1, Conflicts) of
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
	end, [], PAReq#preaccept_request.deps),

	SeqNew = case ets:lookup(maxSeqPerKey, PAReq#preaccept_request.cmd#eepaxos_command.key) of
		[] -> PAReq#preaccept_request.seq;
		[{_, MaxSeq} | _T] -> 
			SeqNewCandid = MaxSeq + 1,
			if 
				SeqNewCandid > PAReq#preaccept_request.seq -> 
					put(Updated, true),
					SeqNewCandid;
				true -> PAReq#preaccept_request.seq
			end
	end,

	% update local data
	ets:insert(inst, #inst{
		ballot = PAReq#preaccept_request.ballot
		,key = PAReq#preaccept_request.inst_key
		, cmd  = PAReq#preaccept_request.cmd
		, deps = PAReq#preaccept_request.deps
		, seq = SeqNew
		, state = preaccepted}),
	
	ets:insert(maxSeqPerKey, {PAReq#preaccept_request.cmd#eepaxos_command.key, SeqNew}),

	ConfName = list_to_atom("conf_" ++ atom_to_list(element(1, PAReq#preaccept_request.inst_key))),
	ConfForR = get(ConfName),

	case lists:keyfind(PAReq#preaccept_request.cmd#eepaxos_command.key, 1, ConfForR) of
		false -> put(ConfName, [{PAReq#preaccept_request.cmd#eepaxos_command.key, element(1,  PAReq#preaccept_request.inst_key)} | ConfForR]);
		_ -> put(ConfName, 
				lists:keyreplace(PAReq#preaccept_request.cmd#eepaxos_command.key
						, 1
						, ConfForR
						, {PAReq#preaccept_request.cmd#eepaxos_command.key, element(1,  PAReq#preaccept_request.inst_key)}))
	end,

	Change = 
	case get(Updated) of
		false ->
			Command1 = Deps2 = Seq1 = undefined,  % set undefined for efficiency
			no_change;
		true -> 
			Command1 = PAReq#preaccept_request.cmd,
			Deps2 = Deps1,
			Seq1 = SeqNew,
			changed
	end,
	erase(Updated),

	rpc:call(PAReq#preaccept_request.leader, eepaxos_process, preaccept_handle, [
			#preaccept_response{inst_key = PAReq#preaccept_request.inst_key
					, cmd =  Command1
					, deps = Deps2
					, seq = Seq1
					, is_changed = Change
			}]),
	State;
do_preaccept_req(State, _, _) -> State.

do_preaccept_resp_merge(State, PAResp, Inst) when PAResp#preaccept_response.is_changed =:=true ->
	error_logger:info_msg("changed received~n"),
	#inst{deps = DepsOrigin, seq = SeqOrigin} = Inst,

	%merge deps
	DepsResult = lists:foldr(fun({ReplicaIdOrigin, InstNoOrigin} = DOrigin, Accum) ->
		{_, InstNoIn} = lists:keyfind(ReplicaIdOrigin, 1, PAResp#preaccept_response.deps),
		if
			InstNoIn > InstNoOrigin -> [{ReplicaIdOrigin, InstNoIn} | Accum];
			true -> [{ReplicaIdOrigin, InstNoOrigin} | Accum]
		end
	end, [], DepsOrigin),
	%merge seq
	SeqResult = if SeqOrigin > PAResp#preaccept_response.seq -> SeqOrigin; true -> PAResp#preaccept_response.seq end,

	InstNew = #inst{key = PAResp#preaccept_response.inst_key
				, ballot = Inst#inst.ballot
				, cmd  = PAResp#preaccept_response.cmd
				, deps = DepsResult
				, seq = SeqResult},
	ets:insert(inst, InstNew),
	ets:update_element(lbk, PAResp#preaccept_response.inst_key, {#lbk.allequal, false}),
	error_logger:info_msg("updated local instance record with the change~n"),
	{State, InstNew};

do_preaccept_resp_merge(State, PASresp, Inst) ->
	error_logger:info_msg("no_change received~n"),
	{State, Inst}.
	
prepare_quorum_process(State, RecoveryInst, Lbk) when State#state.numToSend > Lbk#lbk.prepareoks ->
	State;
prepare_quorum_process(State, RecoveryInst, Lbk) when recoveryInst =/= false -> 
	if  RecoveryInst#recoveryInst.state =:= accepted ->
		% perform accept
			runAccept(node(), 
				RecoveryInst#recoveryInst.leaderId
				, ReplicaId
				, InstNo
				, Command, Deps, Seq
				, State);

		RecoveryInst#recoveryInst.preacceptCnt >= State#state.numToSend -> 
			% all returned same preaccept with default ballot and none of them are original leader
			runAccept(LeaderId, ReplicaId, InstNo, Command, Deps, Seq, State);
		RecoveryInst#recoveryInst.state =:= preaccepted -> % at least one preaccepted returned
			startPhase1();% with preaccept
		true ->
			startPhase1() % with no-op
	end,
	State;
prepare_quorum_process(State, RecoveryInst, Lbk) ->
% quorum has met, but no recovery instance. probably happens when all the responds are returned with higher ballot and NACK. Maybe we should return NACK.
	startPhase1(), %with no-op
	State.

runPreaccepPhase(Ballot, State) ->
ok.

%start accept phase
runAccept({LeaderId, ReplicaId, InstNo, Command, Deps, Seq}, State) ->
	error_logger:info_msg("leader executes process:runAccept~n"),
	ets:update_element(inst, {ReplicaId, InstNo}, {#inst.state, accepted}),
	ets:update_element(lbk, {ReplicaId, InstNo}, {#lbk.acceptoks, 1}),
	%rpc:multicall(State#state.replicas, eepaxos_process, paxos_accept_request, [ReplicaId, InstNo, Command, Deps, Seq]).
	make_call(lists:subtract(State#state.replicas, [node()]), State#state.numToSend, eepaxos_process, paxos_accept_request, [ReplicaId, InstNo, Command, Deps, Seq]),
	error_logger:info_msg("finishing executes process:runAccept~n").

%start commit phase
runCommit(Inst, Lbk, State) ->
	% update local instance
	DBUpdated = ets:update_element(inst, InstKey, {#inst.state, commited}),
	error_logger:info_msg("~w", [ets:lookup(inst, {ReplicaId, InstNo})]),

	%TODO: notify client 
	
	
	%Broadcast
	make_call(lists:subtract(State#state.replicas, [node()]), length(State#state.replicas)-1, eepaxos_process, commit_request
		, [#commit_request{inst_key = Inst#inst.inst_key
							, cmd = Inst#inst.cmd
							, deps = Inst#inst.deps
							, seq = Inst#inst.seq
						}]),
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
