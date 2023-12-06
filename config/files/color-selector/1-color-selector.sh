function _color_index() {
  local color_count hostname_hash hostname_value
  color_count="$1"
  hostname_hash="$(hostname | sha256sum | awk '{print $1}' | tr '[:lower:]' '[:upper:]')"
  hostname_value="$(( 16#${hostname_hash:(-12)} ))"
  readonly color_count hostname_hash hostname_value

  echo $(( $hostname_value % $color_count ))
}

function select_color() {
  local colors index
  colors=( 1 2 3 4 5 6 )
  index="$(_color_index ${#colors[@]})";
  readonly colors index

  echo ${colors[$index]}
}

function shell_color_fg() {
  local color; color="$1"; readonly color
  echo -e "38;5;$color"
}

function shell_color_bg() {
  local color; color="$1"; readonly color
  echo -e "48;5;$color"
}

export COLOR_SELECTOR_BG=15
export COLOR_SELECTOR_FG=8
export COLOR_SELECTOR_ACTIVE="$(select_color)"
export COLOR_SELECTOR_INACTIVE=10
