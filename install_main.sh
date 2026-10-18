#!/bin/bash

confirm_proceed() {
    echo -n "Are you sure you want to proceed? (double tap y, any other key exits): "
    IFS= read -r -n1 c1
    if [[ "$c1" =~ ^[yY]$ ]]; then
        IFS= read -r -n1 c2
        if [[ "$c2" =~ ^[yY]$ ]]; then

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

echo -e "#!/bin/bash\nsleep 5\nexec /sbin/init_old \"$@\" " > /sbin/init

echo "Making executables"
chmod +x /sbin/init
chmod +x /sbin/init_old
chmod +x /sbin/init_backup


