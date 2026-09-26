#!/usr/bin/env bash
# Bounded DynAlloy analysis of SimpleBank. A check must be unsatisfiable.
# A run must be satisfiable, so the bound is not an empty trace.
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
model="$root/verification/dynalloy/SimpleBank.dals"

if [[ -n "${DYNALLOY_JAR:-}" ]]; then
  jar="$DYNALLOY_JAR"
elif [[ -f "${HOME}/.local/verifiers/dynalloy/dynalloy.jar" ]]; then
  jar="${HOME}/.local/verifiers/dynalloy/dynalloy.jar"
else
  jar="${RUNNER_TEMP:-/tmp}/dynalloy-1.0.0.jar"
  if [[ ! -f "$jar" ]]; then
    echo "downloading DynAlloy 1.0.0"
    curl -fsSL -o "$jar" \
      https://github.com/gregistecco/dynalloy/releases/download/1.0.0/dynalloy.jar
  fi
fi

if [[ -z "${JAVA:-}" ]]; then
  if [[ -x /usr/libexec/java_home ]] && /usr/libexec/java_home -v 21 >/dev/null 2>&1; then
    JAVA="$(/usr/libexec/java_home -v 21)/bin/java"
  else
    JAVA=java
  fi
fi
if [[ -z "${JAVAC:-}" ]]; then
  JAVAC="${JAVA%java}javac"
fi

echo "java: $("$JAVA" -version 2>&1 | head -1)"
echo "jar: $jar"
out=$(mktemp -d)
"$JAVAC" -cp "$jar" -d "$out" "$root/verification/dynalloy/RunDynAlloy.java"
"$JAVA" -cp "$out:$jar" RunDynAlloy "$model"
