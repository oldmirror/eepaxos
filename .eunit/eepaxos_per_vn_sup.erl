-module(eepaxos_per_vn_sup).

-behaviour(supervisor).

%% API
-export([start_link/1]).

%% Supervisor callbacks
-export([init/1]).


start_link(VnodeId) ->
	error_logger:info_msg("vn sup called~n"),
    supervisor:start_link({local, ?MODULE}, ?MODULE, [VnodeId]).


init([Per_vn_key]) ->
	ProcessId = list_to_atom("process_" ++ atom_to_list(Per_vn_key)),

    {ok, {{one_for_all, 3, 60},
        [
			{ProcessId
				, {eepaxos_process, start_link, [ProcessId]}
				, permanent
				, infinity
				, worker
				, [eepaxos_process]}
%			, {list_to_atom("" ++ atom_to_list(Per_vn_key))
%				,{eepaxos_membership, start_link, []}
%				, temporary
%				, infinity
%				, worker
%				, [eepaxos_pervn_sup]}
%			, {list_to_atom("process_" ++ atom_to_list(Per_vn_key))
%				,{eepaxos_executor, start_link, []}
%				, temporary
%				, infinity
%				, supervisor
%				, [eepaxos_pervn_sup]
%			}
		]}}.

