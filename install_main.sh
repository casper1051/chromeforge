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
rm /sbin/init

cat << 'EOF' > "/sbin/init"
#!/bin/sh

auto_find_tty() {
    local kernel_console
    kernel_console=$(cat /proc/cmdline 2>/dev/null | tr ' ' '\n' | grep '^console=' | tail -n 1 | cut -d= -f2 | cut -d, -f1)

    if [ -n "${kernel_console}" ] && [ -c "/dev/${kernel_console}" ]; then
        echo "/dev/${kernel_console}"
    elif [ -c "/dev/tty1" ]; then
        echo "/dev/tty1"
    else
        echo "/dev/console"
    fi
}

TARGET_TTY="$(auto_find_tty)"

echo "Dropping to interactive shell on ${TARGET_TTY}. Type 'exit' to boot normally." > "${TARGET_TTY}"

sh < "${TARGET_TTY}" > "${TARGET_TTY}" 2>&1

echo "Shell exited. Continuing to normal system init..." > "${TARGET_TTY}"

exec /sbin/init_old "$@"
EOF

echo "Making executables"
chmod +x /sbin/init
chmod +x /sbin/init_old
chmod +x /sbin/init_backup


