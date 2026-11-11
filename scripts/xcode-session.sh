#!/bin/bash
# Source this before commands that access Xcode's Apple Account credentials.
# A locked data-protection keychain can make Xcode discard the saved account.
require_unlocked_desktop() {
    local session_state
    if ! session_state=$(ioreg -l -w 0 -n Root -d1); then
        echo "Cannot determine desktop lock state; stopping before accessing Xcode credentials." >&2
        return 1
    fi
    if grep -Eq '"CGSSessionScreenIsLocked"[[:space:]]*=[[:space:]]*Yes' <<< "$session_state" ||
       ! grep -Eq '"kCGSSessionOnConsoleKey"[[:space:]]*=[[:space:]]*Yes' <<< "$session_state"; then
        echo "Unlock the Mac desktop and keep it unlocked during the release, then retry." >&2
        return 1
    fi
}

run_xcode_unlocked() {
    require_unlocked_desktop || return 1
    # Prevent idle display/system sleep for this command only. This does not
    # disable manual locking, so keep the desktop/Screen Sharing session open.
    caffeinate -di xcodebuild "$@"
}
