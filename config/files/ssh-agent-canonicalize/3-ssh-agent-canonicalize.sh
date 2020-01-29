if [ -d "$(ssh_agent_canonicalize_data_dir)" ]; then
  eval $("$(ssh_agent_canonicalize_data_dir)/ssh-agent-canonicalize")
else
  echo ssh-agent-canonicalize Failed! \'$(ssh_agent_canonicalize_data_dir)\' is not a directory >&2
fi
