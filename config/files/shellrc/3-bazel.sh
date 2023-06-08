function b() {
  bazel "$@"
}

function skyquery() {
  bazel query --universe_scope=//... --order_output=no "$@"
}

function filequery() {
  xargs -I{} \
    bazel query "$@" --universe_scope=//... --order_output=no \
    'kind(rule, allrdeps(set({}), 1))'
}

function dir-ccb-somepath() {
  dirpath="$1"
  shift
  universe="//$dirpath"
  files="$(find "$dirpath" -type f | tr '[[:space:]]' ' ')"
  targets="$(bazel query --keep_going --universe_scope="$universe" --order_output=no "kind(rule, allrdeps(set($files), 1))" 2>/dev/null | tr '[[:space:]]' ' ')"
  bazel query "$@" "somepath(//vehicle:l3_ccb_regulated_package, set($targets))"
}
