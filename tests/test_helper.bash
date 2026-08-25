#!/usr/bin/env bash
# Shared bats setup/teardown: stubs gh/claude on PATH via a temp bin dir.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup_stub_path() {
  STUB_BIN="$(mktemp -d)"
  export STUB_BIN
  export PATH="${STUB_BIN}:${PATH}"
}

teardown_stub_path() {
  if [[ -n "${STUB_BIN:-}" && -d "${STUB_BIN}" ]]; then
    rm -rf "${STUB_BIN}"
  fi
}

# Writes an executable stub script named $1 into STUB_BIN with body $2.
write_stub() {
  local name="$1"
  local body="$2"
  cat > "${STUB_BIN}/${name}" <<EOF
#!/usr/bin/env bash
${body}
EOF
  chmod +x "${STUB_BIN}/${name}"
}

setup() {
  setup_stub_path
}

teardown() {
  teardown_stub_path
}
