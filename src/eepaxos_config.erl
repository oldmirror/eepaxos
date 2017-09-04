-module(eepaxos_config).

get_replica_no() ->

get_replica_id() ->
	application:get_env(replicaNo).

get_conf() ->
	application:get_env(configuration).
