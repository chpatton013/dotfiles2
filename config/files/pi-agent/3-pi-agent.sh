export PI_NODE_PREFIX="$(pi_node_data_dir)"
export PATH="$(prepend_pathlist "$PATH" "$PI_NODE_PREFIX/current/bin")"
