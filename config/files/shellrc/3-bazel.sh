function b() {
  bazel "$@"
}

function skyquery() {
  bazel query --universe_scope=//... --order_output=no "$@"
}
