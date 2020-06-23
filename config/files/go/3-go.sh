export GO111MODULE=on

if [ -z "$PATH" ]; then
  export PATH="$HOME/go/bin"
else
  export PATH="$HOME/go/bin:$PATH"
fi
