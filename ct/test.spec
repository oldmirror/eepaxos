{alias, basic, "./basic/"}.

{node, node1, 'a@Sungkyus-MacBook-Pro-2.local'}.
{node, node2, 'b@Sungkyus-MacBook-Pro-2.local'}.
{node, node3, 'c@Sungkyus-MacBook-Pro-2.local'}.

{init, [node1, node2, node3], [{node_start, [{monitor_master, true}]}]}.

{suites, [node1], basic, [basic_test_node1_SUITE]}.
{suites, [node2], basic, [basic_test_node2_SUITE]}.
{suites, [node3], basic, [basic_test_node3_SUITE]}.
