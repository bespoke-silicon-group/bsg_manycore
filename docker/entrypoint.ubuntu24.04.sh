#!/bin/bash
export VIRTUAL_ENV_DISABLE_PROMPT=1
source /opt/venv/bin/activate

# set opam
eval $(opam env --set-root --root=/opt/opam)

exec "$@"
