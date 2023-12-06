function b() {
  bazel "$@"
}

function skyquery() {
  bazel query --universe_scope=//... --order_output=no "$@"
}

function filequery() {
  files=$(cat | tr '[[:space:]]' ' ')
  bazel query "$@" --universe_scope=//... --order_output=no \
    "kind(rule, allrdeps(set($files), 1))"
}
