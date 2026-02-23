function firmware-update --description "Update Lenovo firmware via fwupd"
    echo "🔌 Checking UEFI boot mode..."
    if not test -d /sys/firmware/efi
        echo "❌ Not booted in UEFI mode. Firmware updates won't work."
        return 1
    end

    echo "🔋 Checking AC power..."
    if not cat /sys/class/power_supply/AC/online 2>/dev/null | grep -q 1
        echo "⚠️  AC adapter not detected. Plug in your charger before updating firmware."
        return 1
    end

    echo "🔄 Refreshing firmware metadata from LVFS..."
    sudo fwupdmgr refresh --force
    or return 1

    echo "🔍 Checking for available updates..."
    sudo fwupdmgr get-updates
    or begin
        echo "✅ No firmware updates available."
        return 0
    end

    echo ""
    read --prompt-str "📦 Proceed with installing updates? [y/N] " confirm
    if test "$confirm" = y -o "$confirm" = Y
        sudo fwupdmgr update
        echo "✅ Done! Reboot when ready to apply staged firmware updates."
    else
        echo "Aborted."
    end
end
