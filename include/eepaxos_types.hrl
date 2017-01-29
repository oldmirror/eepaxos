-type eepaxos_operation() :: set | increment | delete | decrement | update.
-type ballot_num() :: {atom(), atom(), atom()}.

-define(ST_UNDETERMINED, undetermined).
-define(ST_PREACCEPTED, preaccepted).
-define(ST_ACCEPTED, accepted).
-define(ST_COMMITTED, committed).
-define(ST_PREPARED, prepared).
-define(ST_EXECUTED, executed).

-type inst_state() :: ?ST_UNDETERMINED| ?ST_PREACCEPTED | ?ST_PREPARED | ?ST_PREACCEPTED | ?ST_COMMITTED | ?ST_EXECUTED.

-record(eepaxos_command, {operation :: eepaxos_operation(), key, value}).

-record(preaccept_request,
		{ballot :: ballot_num()
		, leader
		, inst_key
		, cmd
		, deps :: list()
		, seq}).

-record(preaccept_response,
		{inst_key
		, cmd
		, deps :: list()
		, seq :: integer()
		, is_changed}).

-record(accept_request,
		{ballot :: ballot_num()
		, leader
		, inst_key
		, cmd
		, deps :: list()
		, seq}).

-record(accept_response,
		{inst_key
%		, cmd
%		, deps :: list()
%		, seq :: integer()
		}).

-record(commit_request,
		{inst_key
		, cmd
		, deps :: list()
		, seq :: integer()}).

% recovery messages
-record(prepare_request,
		{ballot :: ballot_num()
		, leader
		, inst_key
		, cmd
		, deps :: list()
		, seq :: integer()}).

-record(prepare_response,
		{ballot :: ballot_num()
		, inst_key
		, cmd
		, deps :: list()
		, seq :: integer()
		, prev_status
		, is_original_leader}).

-record(try_preaccept_request,
		{ballot :: ballot_num()
		, leader
		, inst_key
		, cmd
		, deps :: list()
		, seq :: integer()}).

-record(try_preaccept_response,
		{ballot :: ballot_num()
		, inst_key
		, cmd
		, deps :: list()
		, seq :: integer()
		, is_ogirinal_leader}).

-type state() :: preaccepted | accepted | commited | executed.

-record(inst, {key
		, ballot :: ballot_num()
		, cmd  = #eepaxos_command{}
		, deps = []
		, seq = -1
		, index
		, lowlink
		, onstack
		, state = undefined :: state()
		, last_modified}).
	
-record(lbk, {key
		,maxrecvballot
		,prepareoks = 0 ::integer()
		,allequal
		,preacceptoks = 0 ::integer()
		,acceptoks = 0 ::integer()
		,nacks = 0
		,originaldeps
		,committeddeps
		,preparing
		,tryingtopreaccept
		,possiblequorum
		,clientProposals :: pid() 
		}).

-record(recoveryInst, {key
				, cmd  = #eepaxos_command{}
				, deps = []
				, seq = -1
				, idx
				, lowlin
				, state = undefined :: state()
				, hasOriginalResponded
				, preacceptCnt
				}).
