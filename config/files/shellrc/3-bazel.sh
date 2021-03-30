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
