# eepaxos
Egalitarian Paxos in Erlang

This libarary runs in multiple nodes and guarantees to generates same output. 

Hot to use this library

Starting the application
	Application must be started in each Erlang VM.
	
	application:start(eepaxos).

Initialize local replica
	eepaxos_manager:init(PartitionId, NodeList, LocalNodeID).

	PartitionId: Eralng atom. Used to identify replica in the node.
	NodeList: List of nodes where the replica is expected to be existent. Must be subset of erlang:nodes()
	LocalNodeID: 1 through length(NodeList)

	Run the above command for multipl replicas in the node such as for vnodes. Eepaxos objects for each replica can be identified by ReplicaName.


Starting cluster
	eepaxos_manager:start_cluster(Available, Timeout).
	Avaible -> all | minimum
	all: All the replica
	minimum: Minumum node required = N = F/2 +1 

Joining the cluster
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
