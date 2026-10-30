#!/bin/bash

confirm_proceed() {
    echo -n "Are you sure you want to proceed? (double tap y, any other key exits): "
    IFS= read -r -n1 c1
    if [[ "$c1" =~ ^[yY]$ ]]; then
        IFS= read -r -n1 c2
        if [[ "$c2" =~ ^[yY]$ ]]; then
            echo ""
            return 0
        fi
    fi
    echo -e "\nExiting."
    exit 1
}

echo "This script will make unsupported changes to your device and potentially brick it."
confirm_proceed

echo "Backing up existing files"
cp /sbin/init /sbin/init_old
cp /sbin/init /sbin/init_backup

echo "Overwriting init"
rm -f /sbin/init

#trust its not vibecoded at all on any level

cat << 'EOF' > "/sbin/init"

#!/bin/bash

ORIGINAL_INIT="/sbin/init_old"
LOG="/root/log.txt"
FRECON_TTY="/run/frecon/vt1"

export PATH="/sbin:/bin:/usr/sbin:/usr/bin"

# Verify original init first.
if [[ ! -x "$ORIGINAL_INIT" ]]; then
    echo "FATAL: Original init missing" > /dev/kmsg
    exec /bin/sh
fi

# Initialize logging.
if ! touch "$LOG" 2>/dev/null; then
    exec "$ORIGINAL_INIT" "$@"
fi

exec >> "$LOG" 2>&1

# Enable command tracing and error handling.
set -x
set -E
set -o errtrace

log() {
    echo "[MODMIUM] $*"
    echo "<6>MODMIUM: $*" > /dev/kmsg 2>/dev/null || true
}

# Fail-open handler.
fallback() {
    local reason="$1"

    # Prevent recursive ERR traps.
    trap - ERR
    set +e

    log "FALLBACK: $reason"
    log "Executing original ChromeOS init"

    if [[ -x "$ORIGINAL_INIT" ]]; then
        exec "$ORIGINAL_INIT" "${ORIGINAL_ARGS[@]}"
    fi

    log "FATAL: Original init unavailable"
    exec /bin/sh
}

# Preserve original arguments.
ORIGINAL_ARGS=("$@")

# Capture unexpected command failures.
trap 'fallback "Unexpected error at line $LINENO: $BASH_COMMAND (exit $?)"' ERR

start_frecon() {
    local FRECON=""

    if [[ -x /sbin/frecon-lite ]]; then
        FRECON="/sbin/frecon-lite"
    elif [[ -x /sbin/frecon ]]; then
        FRECON="/sbin/frecon"
    else
        log "No frecon executable found"
        return 1
    fi

    log "Using $FRECON"

    mkdir -p /run/frecon || return 1

    if [[ "$FRECON" == "/sbin/frecon" ]]; then
        /sbin/udevd --daemon || return 1
        udevadm trigger || return 1
        udevadm settle || return 1
    fi

    log "Starting frecon"

    "$FRECON" \
        --enable-vt1 \
        --daemon \
        --no-login \
        --enable-vts \
        --pre-create-vts \
        --num-vts=4 \
        --enable-gfx || return 1

    for ((i=0; i<30; i++)); do
        [[ -e "$FRECON_TTY" ]] && break
        sleep 1
    done

    [[ -e "$FRECON_TTY" ]] || return 1

    log "Frecon VT1 ready"

    printf '\033]switchvt:1\a' > /run/frecon/current || return 1

    {
        echo ""
        echo "================================"
        echo "       MODMIUM BOOT TEST"
        echo "================================"
        echo ""
        echo "Frecon initialized successfully."
        echo ""
        echo "Starting ChromeOS in 3 seconds..."
    } > "$FRECON_TTY" || return 1

    return 0
}

log "Modmium init started"

start_frecon

log "Frecon initialization completed"

sleep 3

log "Starting original ChromeOS init"

trap - ERR
exec "$ORIGINAL_INIT" "${ORIGINAL_ARGS[@]}"

# Only reached if exec fails.
fallback "Original init execution failed"

EOF

echo "Making executables"
chmod +x /sbin/init
chmod +x /sbin/init_old
chmod +x /sbin/init_backup
