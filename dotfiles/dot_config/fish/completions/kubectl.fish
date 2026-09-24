# kubectl Fish completion
# Autoloaded by Fish the first time `kubectl` is completed — not at startup.

# kubectl is not installed by this repo: on WSL hosts /usr/local/bin/kubectl is
# a symlink into Docker Desktop's cli-tools mount, so its version is whatever
# Docker Desktop ships and differs per host. Regenerating here rather than
# committing the generated output keeps the completion matched to that binary.
#
# Fish only autoloads this file when the user actually completes `kubectl`, so
# the cost is one ~50ms exec per shell that uses kubectl, and zero otherwise.
# It stays silent when kubectl is missing or its backing mount is unavailable.
#
# This prints only the completion harness; the harness shells out to
# `kubectl __complete` at TAB time, which resolves live pod and namespace
# names and honours -n.
kubectl completion fish | source
