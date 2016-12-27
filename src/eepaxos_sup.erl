-module(eepaxos_sup).

-behaviour(supervisor).

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
	error_logger:info_msg("sup called"),
    {ok, { {one_for_one, 5, 10}, 
	[
		{eepaxos_vn_parent
		,{eepaxos_vn_parent, start_link, []}
		,temporary
		,infinity
		,supervisor
		,[eepaxos_vn_parent]
		}
	]
	}}.

