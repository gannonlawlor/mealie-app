#!/bin/bash
# Exercise release safety without using real credentials, builds, or git writes.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin"
cat > "$TEST_ROOT/bin/ioreg" <<'EOF'
#!/bin/bash
case "$SESSION_FIXTURE" in
    unavailable) exit 1 ;;
    no-desktop) echo '"IOConsoleUsers" = ()' ;;
    locked) echo '"kCGSSessionOnConsoleKey"=Yes "CGSSessionScreenIsLocked" = Yes' ;;
    relock)
        echo '"kCGSSessionOnConsoleKey"=Yes'
        [[ ! -f "$TEST_CASE/archived" ]] || echo '"CGSSessionScreenIsLocked"=Yes'
        ;;
    unlocked) echo '"kCGSSessionOnConsoleKey"=Yes "CGSSessionScreenIsLocked"=No' ;;
esac
EOF
cat > "$TEST_ROOT/bin/caffeinate" <<'EOF'
#!/bin/bash
echo awake >> "$TEST_CASE/actions"
[[ "$1" == -di ]] || exit 90
shift
exec "$@"
EOF
cat > "$TEST_ROOT/bin/xcodebuild" <<'EOF'
#!/bin/bash
echo "xcodebuild $*" >> "$TEST_CASE/actions"
if [[ "$1" == -exportArchive ]]; then
    exit "${UPLOAD_EXIT:-0}"
fi
touch "$TEST_CASE/archived"
EOF
cat > "$TEST_ROOT/bin/git" <<'EOF'
#!/bin/bash
echo "git $*" >> "$TEST_CASE/actions"
EOF
chmod +x "$TEST_ROOT"/bin/*
export PATH="$TEST_ROOT/bin:$PATH"

run_case() {
    local name=$1 expected=$2
    export SESSION_FIXTURE=$name TEST_CASE="$TEST_ROOT/$name-${UPLOAD_EXIT:-0}"
    mkdir -p "$TEST_CASE/ios/Darwin/MealieApp.xcodeproj" "$TEST_CASE/android/app"
    printf 'MARKETING_VERSION = 1.2.3\nCURRENT_PROJECT_VERSION = 4\n' > "$TEST_CASE/ios/Darwin/MealieApp.xcconfig"
    printf 'MARKETING_VERSION = 1.2.3;\nCURRENT_PROJECT_VERSION = 4;\n' > "$TEST_CASE/ios/Darwin/MealieApp.xcodeproj/project.pbxproj"
    printf 'versionCode = 4\nversionName = "1.2.3"\n' > "$TEST_CASE/android/app/build.gradle.kts"
    : > "$TEST_CASE/actions"
    local status=0
    (cd "$TEST_CASE" && bash "$SCRIPT_DIR/release.sh" patch --yes) > "$TEST_CASE/output" 2>&1 || status=$?
    if [[ "$expected" == success ]]; then
        [[ $status == 0 ]] || { cat "$TEST_CASE/output"; exit 1; }
        [[ $(grep -c '^awake$' "$TEST_CASE/actions") == 2 ]]
        grep -q '^git commit ' "$TEST_CASE/actions"
    else
        if [[ $status == 0 ]]; then
            echo "FAIL: $name unexpectedly released"
            exit 1
        fi
        if grep -q '^git ' "$TEST_CASE/actions"; then
            echo "FAIL: $name reached git after a failure"
            exit 1
        fi
        if [[ "$name" == relock ]]; then
            [[ -f "$TEST_CASE/archived" ]]
            if grep -q 'xcodebuild -exportArchive' "$TEST_CASE/actions"; then
                echo 'FAIL: upload accessed credentials after the desktop locked'
                exit 1
            fi
        elif [[ "$name" != unlocked ]]; then
            [[ ! -s "$TEST_CASE/actions" ]]
            grep -q '^MARKETING_VERSION = 1.2.3$' "$TEST_CASE/ios/Darwin/MealieApp.xcconfig"
        fi
    fi
    echo "PASS: $name (upload exit ${UPLOAD_EXIT:-0})"
}

run_case locked failure
run_case no-desktop failure
run_case unavailable failure
run_case unlocked success
run_case relock failure
export UPLOAD_EXIT=70
run_case unlocked failure
