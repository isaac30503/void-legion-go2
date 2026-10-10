function disk-ops --description 'Disk manager (fixed)'
    # Disks with lsblk + fzf: mount/unmount with udisksctl (it needs the graphical session) and repair NTFS
    # with ntfsfix (package ntfs-3g). From the Arch/Homebrew setup (fish/arch/brew/ on the disk; recipe, step 6).
    # Its texts follow the system's language (__vl_t). Previous name: disk-ops (unchanged).
    functions -q __vl_t; or function __vl_t; printf "$argv[1]\n" $argv[2..-1]; end
    # 1. DATA GENERATION
    # FIX: added the 'p' (-pPo) to get full paths (/dev/sda3)
    set -l list_cmd lsblk -pPo NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT -e7

    set -l h_dev (__vl_t "DEVICE"); set -l h_size (__vl_t "SIZE"); set -l h_type (__vl_t "TYPE")
    set -l h_label (__vl_t "LABEL"); set -l h_mount (__vl_t "MOUNTPOINT")
    set -l selection (eval $list_cmd | awk -v FS='"' -v h1="$h_dev" -v h2="$h_size" -v h3="$h_type" -v h4="$h_label" -v h5="$h_mount" '
        BEGIN {
            # --- WIDTH SETTINGS ---
            # The widths are adjusted a bit more for safety
            fmt = "%-20s  %-20s  %-20s  %-20s  %s\n"

            # The HEADER is printed
            printf fmt, h1, h2, h3, h4, h5
        }
        {
            # Variables (even indexes because of the split on quotes)
            dev=$2; size=$4; type=$6; label=$8; mount=$10

            # Visual cleanup
            if (label == "") label="-"
            if (mount == "") mount=""
            if (type == "")  type="-"

            # The DATA is printed
            printf fmt, dev, size, type, label, mount
        }' | \
                    fzf --height=35% \
                        --layout=reverse \
                        --header-lines=1 \
                        --border \
                        --prompt=(__vl_t "Select > ") \
                        --pointer="➤" \
                        --info=inline)

    if test -z "$selection"
        return 0
    end

    # 2. GET THE DATA BACK
    # Now $1 will be "/dev/sda3" instead of "sda3"
    set -l device (echo $selection | awk '{print $1}')
    set -l fstype (echo $selection | awk '{print $3}')
    set -l mountpoint (echo $selection | awk '{print $5}')

    # 3. ACTIONS MENU (the choice is recognized by its emoji, which does not depend on the language)
    set -l a_mount (__vl_t "▶️  Mount (udisksctl)")
    set -l a_unmount (__vl_t "⏏️  Unmount (udisksctl)")
    set -l a_repair (__vl_t "🚑 Repair NTFS (ntfsfix)")
    set -l a_cancel (__vl_t "❌ Cancel")
    set -l action (printf "%s\n" $a_mount $a_unmount $a_repair $a_cancel | fzf \
                    --height=20% \
                    --layout=reverse \
                    --header=(__vl_t "Managing: %s (%s)" "$device" "$fstype") \
                    --border)

    switch $action
        case "▶️*"
            if test -n "$mountpoint"
                __vl_t "ℹ️  Already mounted on: %s" "$mountpoint"
            else
                __vl_t "📂 Mounting %s..." "$device"
                udisksctl mount -b $device
                if test $status -eq 0; __vl_t "✅ Done."; end
            end

        case "⏏️*"
            __vl_t "⏏️  Unmounting %s..." "$device"
            udisksctl unmount -b $device
            if test $status -eq 0; __vl_t "👋 Done."; end

        case "🚑*"
            if string match -q "*ntfs*" $fstype
                __vl_t "🩹 Running ntfsfix on %s..." "$device"
                sudo ntfsfix -d $device
            else
                __vl_t "⛔ Error: only for NTFS."
            end
    end
end
