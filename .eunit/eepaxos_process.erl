-module(eepaxos_process).
-behavior(gen_server).
-include("../include/eepaxos_types.hrl").
-export([code_change/3,
	handle_info/2,
	terminate/2]).

-export([start_link/2, init/1, 
		propose/3,
		preaccept_request/2,
		preaccept_handle/2,
		paxos_accept_request/2,
		paxos_accept_response/2,
		handle_call/3,
		handle_cast/2, 
		do_preaccept_req/3, 
		do_preaccept_resp_merge/3,
		runCommit/3,
		runAccept/2,
		startPhase1/0,
		commit_request/2,
		make_call/5]).

-record(state, {instNo =0, % instance number
				replicaId = -1, %replica ID
				partitionId, % used to identify membership and executor working on the same vnode
				replicas = [], 
				numToSend = 0 :: integer(),
				totalReplicaNo = 1 :: integer(),
				epoch = 0}).

start_link(PartitionId, ReplicaId) ->
	Pid = list_to_atom(atom_to_list(?MODULE) ++ atom_to_list(PartitionId)),
	error_logger:info_msg("process:start_link ~w~n", [Pid]),
	gen_server:start_link({local, Pid}
						, ?MODULE
						, [PartitionId, ReplicaId]
						, []).

init([PartitionId, ReplicaId]) -> 
	error_logger:info_msg("init"),
	InstTab = ets:new(inst, [ordered_set, named_table, {keypos, #inst.key}, public, {write_concurrency, true}, {read_concurrency, true}]),
	LbkTab = ets:new(lbk, [ordered_set, named_table, {keypos, #lbk.key}, public, {write_concurrency, true}, {read_concurrency, true}]),
	ConfTab = ets:new(conflicts, [set, named_table, public]),

	ets:new(maxSeqPerKey, [ordered_set, named_table, public]),
	Replicas = [1, 2, 3],
	NoFQuorum = trunc(length(Replicas)/2),
	
	 {ok, #state{
		instNo = 0, 
		replicaId = ReplicaId,
		partitionId= PartitionId,
		replicas = Replicas,
		numToSend = NoFQuorum
		}}. 

% local call made by client. Returns after 
-spec propose(atom(), atom(), atom()) -> ok | {error, invalid_param}.
propose(PartitionId, Pid, Command) when record(Command, eepaxos_command) ->
	%Key = Command#eepaxos_command.key
	error_logger:info_msg("process:proposed~n"),
	gen_server:cast(PartitionId, {propose, Pid, Command});

propose(PartitionId, Pid, Command) -> {error, invalid_param}.

commit_request(PartitionId, CommitReq) ->
	error_logger:info_msg("process:commit_reqest~n"),
	gen_server:cast(PartitionId, {commit_request, CommitReq}).

preaccept_request(PartitionId, PAReq) when is_record(PAReq, preaccept_request) ->
	error_logger:info_msg("process:preaccept_request~n, id - ~w", [PartitionId]),
	gen_server:cast(PartitionId, {preaccept_request, PAReq}).

preaccept_handle(PartitionId, PAResp) when is_record(PAResp, preaccept_response) ->
	error_logger:info_msg("process:preaccept_response~n"),
	gen_server:cast(PartitionId, {preaccept_handle, PAResp}).

paxos_accept_request(PartitionId, PAReq) when is_record(PAReq, accept_request) ->
	error_logger:info_msg("process:paxos_accept_request called~n"),
	gen_server:cast(PartitionId, {paxos_accept_request, PAReq}).

paxos_accept_response(PartitionId, PAResp) when is_record(PAResp, accept_response) ->
	error_logger:info_msg("process:paxos_accept_response called~n"),
	gen_server:cast(PartitionId, {paxos_accept_response, PAResp}).

start_prepare(PartitionId, InstKey) ->
	error_logger:info_msg("process:start_prepare~n"),
	gen_server:cast(PartitionId, {start_explicit_prepare, InstKey}).

explicit_prepare_request(PartitionId, EPReq) when is_record(EPReq, prepare_request) ->
	error_logger:info_msg("process:paxos_accept_response called~n"),
	gen_server:cast(PartitionId, {explicit_prepare_request, EPReq}).

explicit_prepare_response(PartitionId, EPResp) when is_record(EPResp, prepare_response)  ->
	error_logger:info_msg("process:paxos_accept_response called~n"),
	gen_server:cast(PartitionId, {explicit_prepare_response, EPResp}).

handle_call(stop, From, State) -> {stop, normal, ok, State};
handle_call(_, From, State) -> {reply, reply, State}.

handle_cast({propose, Pid, Command}, State) ->
	error_logger:info_msg("leader executes handle_call(propose)~n"),
	%propose. Construct the record with depts and seq
	InstNo = State#state.instNo + 1,

	%find depedencies
	Deps = lists:foldl(fun(ReplicaId, Accum) -> 
		case ets:lookup(conflicts, {ReplicaId, Command#eepaxos_command.key}) of
			[] -> [{ReplicaId, -1} | Accum];
			[{_, InstNoConf} | _T] -> [{ReplicaId, InstNoConf} | Accum]
		end
	end, [], State#state.replicas),

	%get seq
	Seq = case ets:lookup(maxSeqPerKey, Command#eepaxos_command.key) of
		[]  -> 1;
		[{K, MaxSeq} | _T]  -> MaxSeq + 1
	end,

	ets:insert(maxSeqPerKey, {Command#eepaxos_command.key, Seq}),
	
	Ballot = {State#state.epoch, 0, State#state.replicaId},
	ets:insert(inst, #inst{
		ballot = Ballot
		,key = {State#state.replicaId, InstNo}
		, cmd  = Command
		, deps = Deps
		, seq = Seq
		, state = preaccepted}),

	ets:insert(lbk, #lbk{key = {State#state.replicaId, InstNo}
%		,maxrecvballot = 
		, allequal = true
		, clientProposals = Pid
%		,originaldeps
%		,committeddeps
		, preparing = false
%		,tryingtopreaccept
%		,possiblequorum
		}),

	ets:insert(conflicts, {{State#state.replicaId,  Command#eepaxos_command.key}, instNo}),
	
	ListToSend = lists:subtract(State#state.replicas, [State#state.replicaId]),
	NumToSend =  State#state.numToSend,
	error_logger:info_msg("preaccept_request send to ~w of ~w~n", [NumToSend, ListToSend]),
	Ok = make_call(ListToSend, NumToSend, eepaxos_process, preaccept_request, 
			#preaccept_request{ballot= Ballot
				, leader = State#state.replicaId
				, inst_key = {State#state.replicaId, InstNo}
				, cmd = Command
				, deps = Deps
				, seq = Seq}
				),

	error_logger:info_msg("finishing handle_call(propose)~n"),

	{noreply, State#state{instNo = InstNo}};

%==================================================================
%	preaccept
% ==================================================================
handle_cast({preaccept_request, PAReq}, State) ->
	error_logger:info_msg("Acceptor(~w) executes handle_cast(preaccept_request)~n", [State#state.replicaId]),
	Inst = ets:lookup(inst, PAReq#preaccept_request.inst_key),
	
	if Inst =/= false andalso Inst#inst.ballot >= PAReq#preaccept_request.ballot -> % already accepted higher ballot
			{noreply, State};
		Inst =/= false andalso 
				(Inst#inst.state == ?ST_ACCEPTED orelse 
				Inst#inst.state == ?ST_COMMITTED orelse 
				Inst#inst.state == ?ST_EXECUTED
				) ->
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
							runAccept({element(1, PARes#preaccept_response.inst_key)
									, element(2, PARes#preaccept_response.inst_key)
									, InstNew#inst.cmd
									, InstNew#inst.deps
									, InstNew#inst.seq}
									, State)
					end
			end,
			error_logger:info_msg("finishing handle_cast(preaccept_response).~n"),
			{noreply, State1}
	end;

handle_cast({paxos_accept_request, AcceptReq}, State) -> 
	error_logger:info_msg("acceptor(~w) executes handle_cast(paxos_accept_request)~n", [State#state.replicaId]),
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
	error_logger:info_msg("acceptor (~w) commit_request - ~w ~w ~w ~w ~w~n", [State#state.replicaId, CommitReq]),
	%update instance with commited state. protocol ends
	ets:insert(inst, CommitReq#commit_request.inst_key
				, #inst{ballot = CommitReq#commit_request.inst_key
					, cmd = CommitReq#commit_request.cmd
					, deps = CommitReq#commit_request.deps
					, seq = CommitReq#commit_request.seq
					, state= commited}),

	eepaxos_execute_process:execute(State#state.partitionId, CommitReq#commit_request.inst_key),
	{noreply, State};

handle_cast({start_explicit_prepare, InstanceKey}, State) ->
	error_logger:info_msg("new leader(~w) start_explicit_prepare- ~w ~w ~w ~w ~w~n", [node(), InstanceKey]),
	
	Inst = ets:lookup(inst, InstanceKey),
	Inst1 = 
	if Inst =:= false ->
			ets:insert(inst, #inst{key=InstanceKey
							, ballot = {State#state.epoch, 1, State#state.replicaId} % no instance. ballot number 1
							, state = undetermined});
		true ->
			#inst{ballot = {E, S, _}, state = St} = Inst,
			NewBallot = {E, S+1, State#state.replicaId}, %TODO: should epoch be from previous record or current state?
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
												if element(1, Inst1#inst.key) == State#state.replicaId -> true;
													 true -> false
												end,
											 preacceptCnt = 1})
			end,

			make_call(lists:subtract(State#state.replicas, [State#state.replicaId]), State#state.numToSend, eepaxos_process,
						explicit_prepare_request, [
							#prepare_request{ballot = Inst#inst.ballot, leader = State#state.replicaId
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
		case ets:lookup(FoldingReplicaId, PAReq#preaccept_request.cmd#eepaxos_command.key) of
			[]-> [DepElem | Accum];
			[{_, InstNoConf} | _] -> 
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

	ets:insert(conflicts, {{element(1, PAReq#preaccept_request.inst_key), PAReq#preaccept_request.cmd#eepaxos_command.key}
					, element(2, PAReq#preaccept_request.inst_key)}),

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
	
	PAResp = #preaccept_response{inst_key = PAReq#preaccept_request.inst_key
					, cmd =  Command1
					, deps = Deps2
					, seq = Seq1
					, is_changed = Change
			},

	make_call([PAReq#preaccept_request.leader], 1, eepaxos_process, preaccept_handle, PAResp),
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
	if  RecoveryInst#recoveryInst.state =:= accepted % any accepted found
		orelse RecoveryInst#recoveryInst.preacceptCnt >= State#state.numToSend -> % all returned same preaccept with default ballot and none of them are original leader
		% perform accept
			runAccept({State#state.replicaId
				, element(1, RecoveryInst#recoveryInst.key)
				, element(2, RecoveryInst#recoveryInst.key)
				, RecoveryInst#recoveryInst.cmd
				, RecoveryInst#recoveryInst.deps
				, RecoveryInst#recoveryInst.seq
				}
				, State);

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
startPhase1() -> ok.

runPreaccepPhase(Ballot, State) ->
ok.

%start accept phase
runAccept({LeaderId, ReplicaId, InstNo, Command, Deps, Seq}, State) ->
	error_logger:info_msg("leader executes process:runAccept~n"),
	ets:update_element(inst, {ReplicaId, InstNo}, {#inst.state, accepted}),
	ets:update_element(lbk, {ReplicaId, InstNo}, {#lbk.acceptoks, 1}),
	%rpc:multicall(State#state.replicas, eepaxos_process, paxos_accept_request, [ReplicaId, InstNo, Command, Deps, Seq]).
	make_call(lists:subtract(State#state.replicas, [State#state.replicaId]), State#state.numToSend, eepaxos_process, paxos_accept_request, [ReplicaId, InstNo, Command, Deps, Seq]),
	error_logger:info_msg("finishing executes process:runAccept~n").

%start commit phase
runCommit(Inst, Lbk, State) ->
	% update local instance
	DBUpdated = ets:update_element(inst, Inst#inst.key, {#inst.state, commited}),
	error_logger:info_msg("~w", [ets:lookup(inst, Inst#inst.key)]),

	%TODO: notify client 
	
	%Broadcast
	make_call(lists:subtract(State#state.replicas, [State#state.replicaId]), length(State#state.replicas)-1, eepaxos_process, commit_request
		, [#commit_request{inst_key = Inst#inst.key
							, cmd = Inst#inst.cmd
							, deps = Inst#inst.deps
							, seq = Inst#inst.seq
						}]),
	State.

code_change(_OldVsn, _State, _Extra) -> ok.
handle_info(_Info, _State) -> ok.
terminate(_Reason, _State) -> ok.

-ifdef(debug).
make_call(NodeList, Num, Module, Fun, Args) ->
	error_logger:info_msg("make_call called ~w~n", [Args]),
	ets:insert(test_result, {1, Args}),
	[{2, E}] = ets:lookup(test_result, 2),
	error_logger:info_msg("PID to return - ~w", [E]),
	E ! msg.

-else.
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
-endif.
