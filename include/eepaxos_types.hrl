-type eepaxos_operation() :: set | increment | delete | decrement | update.

-record(eepaxos_command, {operation :: eepaxos_operation(), key, value}).
