
-type state :: norm | view_change | transitioning

-define(ETS, log_table).
-record(st, {clientTable = []
			, commitNo = 0
			, opNo = 0
			}),

init() ->
	ets:init(?ETS, [set, named_table, public]),
	ets:insert({}, {}),
	#st{}.

handle_cast({prepareOk, Data}, State) ->
	ok.

executor(CommitNo, OpNo) ->
	recordSt = ets:lookup_element(?ETS, 
	ets:update_element(?ETS, {}), 
	
%Normal operations
prepare(State) ->
	

prepare_ok(State) ->
	
% view change protocol
		
view_change(State) ->
	State1 = State#state{state = view_change, view_change_table=[]},
	send_all({start_view_change

do_view_change(State) ->


start_view(State) ->

	



%recovery protocol
recovery_req(State) ->
	State1 = State#state{state = recovering, recovery_info = [{remaining_resp_cnt, 3} , {primary_req = {}}]},
	send_all({recovery, State#state.replicaNo, Nonce}),
	State1.

recovery_resp(State) ->
	State1 = State#state{state = recoverin},
	

	State1.

rejoin(State) ->
	State1 = node_sync(State),
	recovery(State1).

state_transfer(State, OpNo) ->
	State1 = node_sync(State),
	newState(State, OpNo).

node_sync(State) ->
	State1 = chkpnt sync_with(State#state.view),
	% chkPnt updated

new_state() ->
