-module(eepaxos_config).

get_replica_no() ->
3.

get_replica_id() ->
	application:get_env(replicaNo).
