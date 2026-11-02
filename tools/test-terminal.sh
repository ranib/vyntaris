#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
qml="$(command -v qml6 || command -v qml || echo /usr/lib/qt6/bin/qml)"
QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen "$qml" tools/qml-tests/Terminal.qml 2>&1 | sed 's/^qml: //'
exit "${PIPESTATUS[0]}"
