if [ -d "$(worktree_data_dir)" ]; then
  source "$(worktree_data_dir)/worktree.sh"

  function wt() {
    worktree "$@"
  }

  function wt_create() {
    worktree_create "$@"
  }

  function wt_resume() {
    worktree_resume "$@"
  }
fi
