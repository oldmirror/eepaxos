-module(eepaxos_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
	error_logger:info_msg("app called~n"),
    eepaxos_sup:start_link().

stop(_State) ->
    ok.
