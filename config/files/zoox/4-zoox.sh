export WORKTREE_WORKTREE_ROOT=~/driving
export WORKTREE_PRIMARY_PROJECT=root
export WORKTREE_BRANCH_NAME_PREFIX=user/chris/
#export WORKTREE_BRANCH_NAME_SUFFIX=""
#export WORKTREE_BASE_BRANCH=master
#export WORKTREE_REMOTE=origin
WORKTREE_ENVIRONMENT_ENTRYPOINT=
WORKTREE_ENVIRONMENT_ENTRYPOINT+='builtin cd "$project_directory"'
WORKTREE_ENVIRONMENT_ENTRYPOINT+=' && tmux has-session -t "$project_name" 2>/dev/null'
WORKTREE_ENVIRONMENT_ENTRYPOINT+=' && tmux attach -t "$project_name"'
WORKTREE_ENVIRONMENT_ENTRYPOINT+=' || tmux new -s "$project_name"'
export WORKTREE_ENVIRONMENT_ENTRYPOINT

PATH+=":/opt/zoox/bin"

export VLR_ROOT="$HOME"
zooxrc="$(worktree_active_project_worktree)/scripts/shell/zooxrc.sh"
if [ -f "$(readlink -e "$zooxrc")" ]; then
  source "$zooxrc"
fi

export VAULT_ADDR='https://vault.zooxlabs.com:8200'
alias aws-mfa='oathtool --totp --base32 -w 1 "`cat ~/.aws/oathtool-mfa`"'
alias vault-auth='vault login -method=oidc username=chris'

if which hub >/dev/null; then
  alias git=hub
fi
export HUB_PROTOCOL=git
export GITHUB_HOST=git.zooxlabs.com
if [ -f "$(readlink -e ~/.github-token)" ]; then
  export GITHUB_TOKEN="$(cat ~/.github-token)"
fi
export GITHUB_USER=chris
export GITHUB_REPOSITORY=zooxco/driving

export dz=develop/zrn
export rz=release/zrn
export dc=develop/carta
export rc=release/carta

export odz=origin/develop/zrn
export orz=origin/release/zrn
export odc=origin/develop/carta
export orc=origin/release/carta

export KUBECONFIG="$HOME/.kube/config"

function coowners() {
  git grep -l "$@" -- '*OWNERS' |
    xargs -I{} sh -c 'echo \#\#\# {}; cat {}; echo'
}

function dir-ccb-somepath() {
  dirpath="$1"
  shift
  universe="//$dirpath"
  files="$(find "$dirpath" -type f | tr '[[:space:]]' ' ')"
  targets="$(bazel query --keep_going --universe_scope="$universe" --order_output=no "kind(rule, allrdeps(set($files), 1))" 2>/dev/null | tr '[[:space:]]' ' ')"
  bazel query "$@" "somepath(//vehicle:l3_ccb_regulated_package, set($targets))"
}
