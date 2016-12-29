-module(eepaxos_vn_parent).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).


start_link() ->
	error_logger:info_msg("parent called~n"),
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


init([]) ->
    {ok, {{simple_one_for_one, 3, 60},
        [{doesnt_matter, 
			{eepaxos_per_vn_sup, start_link, []}
			, temporary
			, infinity
			, supervisor
			, [eepaxos_per_vn_sup]
		}]}
		}.

