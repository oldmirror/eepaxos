-module(eepaxos_process_sup).
-behavior(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    {ok, { {simple_one_for_one, 5, 10}, 
	[
		{eepaxos_process % per replica process
		,{eepaxos_process, start_link, []}
		,permanent
		,infinity
		,worker
		,[eepaxos_process]
		}
	]
	}}.

create_replica(Replicas) ->
	supervisor:start_child(eepaxos_process_sup, eepaxos_).
