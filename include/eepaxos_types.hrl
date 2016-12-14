-type eepaxos_operation() :: set | increment | delete | decrement | update.
-type ballot_num() :: {atom(), atom(), atom()}.
-type inst_state() :: undetermined | preaccepted | prepared | accepted | committed | executed.

-record(eepaxos_command, {operation :: eepaxos_operation(), key, value}).

-record(preaccept_request,
		{ballot :: ballot_num()
		, leader
		, replicaId
		, instNo
		, cmd}).
	
		

