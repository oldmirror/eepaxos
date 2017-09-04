# eepaxos
Egalitarian Paxos in Erlang

This libarary runs in multiple nodes and guarantees to generates same output. 

Hot to use this library

Architecture



Starting the application
	Application must be started in each Erlang VM.
	
	application:start(eepaxos).

Initialize local replica
	eepaxos_manager:init(PartitionId, NodeList, LocalNodeID).

	PartitionId: Eralng atom. Used to identify replica in the node.
	NodeList: List of nodes where the replica is expected to be existent. Must be subset of erlang:nodes()
	LocalNodeID: 1 through length(NodeList)

	Run the above command for multipl replicas in the node such as for vnodes. Eepaxos objects for each replica can be identified by ReplicaName.

	In case where there are multiple replica sets for a node, eepaxos should be instantiated as many as the number of replica sets. 


Starting cluster
	eepaxos_manager:start_cluster(Available, Timeout).
	Avaible -> all | minimum
	all: All the replica
	minimum: Minumum node required = N = F/2 +1 

Recovery
	After a node crashes, other nodes in the cluster are likely to advance. Since we assume client application takes snapshot 
and stores checkpoint when Eepaxos notifies, recovering node only need to pull in log entries after checkpoint from other nodes.
It should only pull in committed entries.
Checkpoint could take place and logs are discarded in all the other nodes. In this case, client app should Once the recovering node is brought to some point and join the communication,
its executor will initiate explicit prepare so missing logs will be filled in. Requests sent after node becomes online will be appended 
as normally.

	* Most database systems have redo logs to avoid frequent disk writes. This log file is often located in separate I/O port in sequential access media.
	write operations take place in memory changing contents. We should assume that Eepaxos execute up-call performs write to log file of client system.
	In this case, every execute operation of eepaxos can be viewed as checkpoint.

Joining the cluster(reconfiguration)
	
	eepaxos_manager:join(NodeList).

Proposing operations
	client application might receive end user request to apply operation in the partition and dispatch the request to a node where there are replica 
	of the partition. Below 
	
	eepaxos_frontend:call(PartitionId, Command) -> ok | {error, Reason}
	eepaxos_frontend:cast(PartitionId, Command) -> Key
	Reason: 
		exceed_failure_tolerant - number of failed replica nodes is above failure tolerant(N = F/2 +1. ex: when N is 5, 3 is required to run )
		timeout - timed out because of 


	On the successful proposal, it return to the client. In the background, eepaxos performs consensus algorithm and execute 

Integration execution engine
	eepaxos needs to know how to perform execution(actual write) to the client data set so integration work is required.  
Sample

