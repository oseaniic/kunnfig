#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║      Osean's Arch Install Script — Tsundere Edition v2       ║
# ║   Run from Arch live ISO. Do NOT pre-run cfdisk manually.    ║
# ╚══════════════════════════════════════════════════════════════╝

# ── Global State ─────────────────────────────────────────────────────────────
INPUT_PARENT=""
INPUT_EFI=""
USE_SWAP=false
INPUT_SWAP=""
INPUT_FILESYSTEM=""
INPUT_SYSTEMNAME=""
INPUT_USERNAME=""
INPUT_PASSWORD=""
ROOT_ENABLED=false
ROOT_PASSWORD=""
SELECTED_LOCALES=()
SELECTED_KEYMAP="us"
INSTALL_YAY=false
INSTALL_SDDM=false
GPU_TYPE="broke"
DETECT_OS=false
AUTOLOGIN=false
OPTIONAL_PACKAGES=()
PUNISH_IDX=0

# ── Colours (terminal only, never passed into dialog) ─────────────────────────
B=$'\033[1m';  R=$'\033[0m'
CY=$'\033[36m'; YL=$'\033[33m'; RD=$'\033[31m'
GR=$'\033[32m'; MG=$'\033[35m'

# ── Tsundere messages (terminal) ──────────────────────────────────────────────
t_reinstall() {
    echo -e "${MG}${B}...AGAIN?? seriously, AGAIN?? what did you even DO to the last one?"
    echo -e "d-don't answer that. let's just get this over with. baka.${R}"
}
t_noyay()       { echo -e "${YL}${B}no yay?! fine!! enjoy typing full AUR URLs like an animal. idiot.${R}"; }
t_nosddm()      { echo -e "${YL}${B}no display manager. okay mr. soy terminal-login. whatever.${R}"; }
t_nobios()      { echo -e "${YL}${B}not detecting other OSes? baka. hope you don't regret that later.${R}"; }
t_nopkgs()      { echo -e "${MG}${B}k. that was the last time i do anything nice for you. hmp.${R}"; }
t_broke()       { echo -e "${YL}${B}no GPU drivers. broke boi confirmed. i'm not judging. (i'm judging.)${R}"; }
t_noautologin() { echo -e "${CY}${B}no autologin. okay. you enjoy typing your password. masochist.${R}"; }

# ── Tsundere messages (dialog-safe, plain text) ───────────────────────────────
DT_GREET="...again?? SERIOUSLY?? what happened to the last install?!\nYou know what, fine. let's do this. b-baka."
DT_NOPWD_MATCH="th-those passwords don't match!! how are you even a computer person?! try again!!"
DT_ATLEAST1="you HAVE to pick at LEAST one locale, baka!! what were you thinking?!"
DT_SAMEPWD="...that's the SAME password as your user account, you absolute disaster.\nLinux purists are weeping somewhere. But it's technically fine so... whatever.\n(linux redditors do NOT recommend this but im not ur mom)"
DT_PUNISH_OK="...f-fine. i'll allow it. don't make me regret this, got it?"
DT_PUNISH_FAIL="WRONG!! you can't even type a simple string?! pathetic!!\nTry again or just give up already!!"
DT_NOPKGS="k. that was the last time i do anything nice for you. hmp."

# ── Punishment strings (case-sensitive, must be typed exactly) ─────────────────
PUNISH_STRINGS=(
    "I'm sorry boss, please allow me to retry."
    "Forgive me, I made an error and wish to correct it."
    "My deepest apologies, may I please try once more."
    "I humbly request permission to redo this section."
    "I acknowledge my mistake and ask for another chance."
    "Please, I'll do better this time, I solemnly promise."
    "Pardon my error, I would like to try once more."
    "I messed up and take full responsibility. Retry please."
    "One more chance is all I ask. I won't let you down."
    "Sincerely sorry for the trouble. Permission to retry?"
)

# ── Dialog result capture ──────────────────────────────────────────────────────
TMPF=$(mktemp)
trap 'rm -f "$TMPF"' EXIT
DIALOG_OUT=""

run_dialog() {
    # Usage: run_dialog [dialog flags...]
    # Result in $DIALOG_OUT; returns dialog exit code
    dialog --backtitle "Osean's Arch Installer — Tsundere Edition" "$@" 2>"$TMPF"
    local rc=$?
    DIALOG_OUT=$(cat "$TMPF")
    return $rc
}

# ── Horizontal arrow-key menu ──────────────────────────────────────────────────
# Sets $HMENU_RESULT to index of chosen item.
# Usage: hmenu "Prompt line" opt1 opt2 opt3 ...
hmenu() {
    local prompt="$1"; shift
    local opts=("$@")
    local sel=0 n=${#opts[@]}

    printf '\n%s\n\n' "${B}${prompt}${R}"
    tput civis 2>/dev/null || true

    while true; do
        printf '\r  '
        for i in "${!opts[@]}"; do
            if (( i == sel )); then
                printf '%s' "${B}${CY}[ ${opts[$i]} ]${R}  "
            else
                printf '  %s   ' "${opts[$i]}"
            fi
        done
        printf '    '

        IFS= read -rsn1 key
        if [[ "$key" == $'\033' ]]; then
            IFS= read -rsn2 -t0.1 seq || true
            [[ "$seq" == '[C' ]] && (( sel < n-1 )) && (( sel++ ))
            [[ "$seq" == '[D' ]] && (( sel > 0  )) && (( sel-- ))
        elif [[ "$key" == '' ]]; then
            break
        fi
    done

    tput cnorm 2>/dev/null || true
    printf '\n\n'
    HMENU_RESULT=$sel
}

# ── Disk helpers ──────────────────────────────────────────────────────────────
get_disks() { lsblk -d -n -o NAME,TYPE | awk '$2=="disk"{print $1}'; }

# Outputs "name size" pairs, one per line, for partitions of given disk
get_parts_raw() { lsblk -n -o NAME,SIZE,TYPE "/dev/$1" 2>/dev/null | awk '$3=="part"{print $1, $2}'; }

# Builds a dialog menu item list into an array variable named by $1
# Usage: build_part_items result_array_name disk [exclude1 exclude2 ...]
build_part_items() {
    local -n _ref=$1; shift
    local disk="$1";  shift
    local excludes=("$@")
    _ref=()
    while IFS= read -r line; do
        local pname psize
        pname=$(awk '{print $1}' <<<"$line")
        psize=$(awk '{print $2}' <<<"$line")
        local skip=false
        for ex in "${excludes[@]}"; do [[ "$pname" == "$ex" ]] && skip=true && break; done
        $skip || _ref+=("$pname" "$psize")
    done < <(get_parts_raw "$disk")
}

# ── Setup: install dialog from live ISO pacman ─────────────────────────────────
setup_tools() {
    clear
    echo -e "${CY}Setting things up before we can actually talk to you properly...${R}"
    pacman -S --needed --noconfirm dialog 2>/dev/null || true
}

# ── Network check ──────────────────────────────────────────────────────────────
check_network() {
    if ! ping -q -c1 -W3 archlinux.org &>/dev/null; then
        echo -e "${RD}${B}Error: No network! Fix your internet first, baka!${R}"
        exit 1
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 1 — Drive & Partition Selection
# ═════════════════════════════════════════════════════════════════════════════
section_1() {
    while true; do
        # ── 1a. Pick parent drive ────────────────────────────────────────────
        clear
        echo -e "${B}${CY}══ SECTION 1 — Drive & Partition Setup ══${R}\n"
        lsblk
        echo ""

        mapfile -t DISKS < <(get_disks)
        if [[ ${#DISKS[@]} -eq 0 ]]; then
            echo -e "${RD}${B}No disks found. how do you even have a computer?? exiting.${R}"
            exit 1
        fi

        hmenu "Select your target drive   ←  →   Enter to confirm:" "${DISKS[@]}"
        local chosen_disk="${DISKS[$HMENU_RESULT]}"

        # ── 1b. Confirm / manage / repick ────────────────────────────────────
        local part_ok=false
        while ! $part_ok; do
            clear
            echo -e "${B}${CY}══ Drive selected: /dev/${chosen_disk} ══${R}\n"
            lsblk "/dev/$chosen_disk"
            echo ""

            hmenu "What now?" \
                "Continue" \
                "Manage Partitions" \
                "Pick Different Drive"

            case $HMENU_RESULT in
                0)  part_ok=true ;;
                1)  cfdisk "/dev/$chosen_disk" || true
                    clear ;;
                2)  continue 2 ;;  # restart outer loop → re-pick drive
            esac
        done

        # ── 1c. Check partition count ─────────────────────────────────────────
        local all_items=()
        build_part_items all_items "$chosen_disk"
        if [[ ${#all_items[@]} -lt 4 ]]; then   # need at least 2 partitions (4 elements)
            run_dialog --title "Not enough partitions" \
                --msgbox "i found fewer than 2 partitions on /dev/${chosen_disk}.\nYou need at minimum an EFI + filesystem partition.\nGo manage those first, baka." \
                9 62
            continue
        fi

        # ── 1d. EFI partition ─────────────────────────────────────────────────
        run_dialog --title "EFI Partition" \
            --menu "Select the EFI partition (recommended: 100–300 MB, will be FAT32)" \
            20 72 10 "${all_items[@]}" || continue
        local chosen_efi="$DIALOG_OUT"

        # ── 1e. Swap (optional) ───────────────────────────────────────────────
        local use_swap=false chosen_swap=""
        if run_dialog --title "Swap Partition" \
               --defaultno \
               --yesno "Do you want a swap partition?\n(Optional on modern systems with plenty of RAM)" \
               8 62; then
            use_swap=true
            local no_efi_items=()
            build_part_items no_efi_items "$chosen_disk" "$chosen_efi"
            if [[ ${#no_efi_items[@]} -lt 2 ]]; then
                run_dialog --title "Not enough partitions" \
                    --msgbox "No remaining partitions for swap after selecting EFI.\nSkipping swap." 7 60
                use_swap=false
            else
                run_dialog --title "Swap Partition" \
                    --menu "Select the swap partition (recommended: 4 GB or 8 GB)" \
                    20 72 10 "${no_efi_items[@]}" || continue
                chosen_swap="$DIALOG_OUT"
            fi
        fi

        # ── 1f. Filesystem partition ─────────────────────────────────────────
        local fs_items=()
        build_part_items fs_items "$chosen_disk" "$chosen_efi" "$chosen_swap"
        if [[ ${#fs_items[@]} -lt 2 ]]; then
            run_dialog --title "Not enough partitions" \
                --msgbox "No partitions left for filesystem! Go back and fix your partitions." 7 60
            continue
        fi
        run_dialog --title "Filesystem Partition" \
            --menu "Select the main filesystem partition\n  30 GB → bare-bones   50 GB → standard\n  80 GB → recommended  150 GB+ → heavy user" \
            20 72 10 "${fs_items[@]}" || continue
        local chosen_fs="$DIALOG_OUT"

        # ── 1g. Summary + confirm ─────────────────────────────────────────────
        local swap_line
        $use_swap && swap_line="Swap:         /dev/${chosen_swap}" \
                  || swap_line="Swap:         (none)"
        local lsblk_out
        lsblk_out=$(lsblk)

        run_dialog --title "Partition Summary — does this look right?" \
            --yesno "Drive:        /dev/${chosen_disk}\nEFI:          /dev/${chosen_efi}\n${swap_line}\nFilesystem:   /dev/${chosen_fs}\n\n${lsblk_out}" \
            30 78 || continue

        # Commit values
        INPUT_PARENT="$chosen_disk"
        INPUT_EFI="$chosen_efi"
        USE_SWAP=$use_swap
        INPUT_SWAP="$chosen_swap"
        INPUT_FILESYSTEM="$chosen_fs"
        return 0
    done
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 2 — System Name, Username & Password
# ═════════════════════════════════════════════════════════════════════════════
section_2() {
    while true; do
        # System name
        run_dialog --title "System Name" \
            --inputbox "Enter a hostname for this system:" 8 60 || continue
        local sysname="$DIALOG_OUT"
        [[ -z "$sysname" ]] && { run_dialog --title "!!" --msgbox "...a blank hostname. really. really??" 6 44; continue; }

        # Username
        run_dialog --title "Username" \
            --inputbox "Create a username (lowercase, no special characters):" 8 60 || continue
        local uname="$DIALOG_OUT"
        if [[ -z "$uname" ]] || [[ ! "$uname" =~ ^[a-z][a-z0-9_-]*$ ]]; then
            run_dialog --title "!!" --msgbox "Invalid username. lowercase letters/numbers/underscores only, baka." 7 60
            continue
        fi

        # Password loop
        local pwd1 pwd2
        while true; do
            run_dialog --title "Password" \
                --passwordbox "Create a password for user '${uname}':" 8 60 || break 2
            pwd1="$DIALOG_OUT"
            run_dialog --title "Password (confirm)" \
                --passwordbox "Retype the password:" 8 60 || break 2
            pwd2="$DIALOG_OUT"
            if [[ "$pwd1" != "$pwd2" ]]; then
                run_dialog --title "!!" --msgbox "$DT_NOPWD_MATCH" 7 66
            else
                break
            fi
        done

        # Summary + continue / retry / test password
        while true; do
            run_dialog --title "Meta Summary — look right?" \
                --menu "System:    ${sysname}\nUser:      ${uname}\nPassword:  ********\n" \
                14 60 3 \
                "continue" "Looks good, move on" \
                "retry"    "Something's wrong, redo this" \
                "test"     "Let me test my password real quick" || break 2

            case "$DIALOG_OUT" in
                continue) break 2 ;;
                retry)    break ;;  # outer while → redo from top
                test)
                    run_dialog --title "Password Test" \
                        --passwordbox "Type your password now:" 8 60 || continue
                    if [[ "$DIALOG_OUT" == "$pwd1" ]]; then
                        run_dialog --title "Password Test" --msgbox "yep. that's the one. happy now?" 6 44
                    else
                        run_dialog --title "Password Test" --msgbox "...WRONG. you have a problem. retry recommended." 6 52
                    fi
                    ;;
            esac
        done
    done

    INPUT_SYSTEMNAME="$sysname"
    INPUT_USERNAME="$uname"
    INPUT_PASSWORD="$pwd1"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 3 — Root / Administrator Account
# ═════════════════════════════════════════════════════════════════════════════
section_3() {
    ROOT_ENABLED=false
    ROOT_PASSWORD=""

    if ! run_dialog --title "Root Account" \
           --defaultno \
           --yesno "Enable the root (administrator) account?\n\nThis is an old-school thing most modern systems don't need.\nI personally have never used it. Just saying.\nThe default username for root login is 'root' and cannot be changed here." \
           12 68; then
        return 0
    fi

    # User wants root enabled — get password
    while true; do
        local r1 r2
        run_dialog --title "Root Password" \
            --passwordbox "Set a password for the root account\n(login username is: root)" 9 60 || { ROOT_ENABLED=false; return 0; }
        r1="$DIALOG_OUT"
        run_dialog --title "Root Password (confirm)" \
            --passwordbox "Retype root password:" 8 60 || { ROOT_ENABLED=false; return 0; }
        r2="$DIALOG_OUT"

        if [[ "$r1" != "$r2" ]]; then
            run_dialog --title "!!" --msgbox "$DT_NOPWD_MATCH" 7 66
            run_dialog --title "Root Password" \
                --menu "What do you want to do?" 9 56 2 \
                "retry"    "Try entering root password again" \
                "nevermind" "Forget it, disable root account" || { ROOT_ENABLED=false; return 0; }
            [[ "$DIALOG_OUT" == "nevermind" ]] && { ROOT_ENABLED=false; return 0; }
            continue
        fi

        # Warn if root password same as user password
        if [[ "$r1" == "$INPUT_PASSWORD" ]]; then
            run_dialog --title "uh... same password??" \
                --menu "$DT_SAMEPWD" \
                16 72 3 \
                "continue"  "Yes i'm sure, use same password" \
                "retry"     "Let me pick a different root password" \
                "nevermind" "Actually forget the root account" || { ROOT_ENABLED=false; return 0; }
            case "$DIALOG_OUT" in
                continue)  break ;;
                nevermind) ROOT_ENABLED=false; return 0 ;;
                retry)     continue ;;
            esac
        else
            break
        fi
    done

    ROOT_ENABLED=true
    ROOT_PASSWORD="$r1"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 4 — Locale & Keyboard Layout
# ═════════════════════════════════════════════════════════════════════════════
# Locale tag → full locale string mapping
declare -A LOCALE_MAP=(
    ["en_US"]="en_US.UTF-8 UTF-8"
    ["ja_JP"]="ja_JP.UTF-8 UTF-8"
    ["es_PE"]="es_PE.UTF-8 UTF-8"
)

section_4() {
    while true; do
        # ── Locale checklist ──────────────────────────────────────────────────
        local raw_locales=()
        while true; do
            run_dialog --title "Locale Selection" \
                --separate-output \
                --checklist "Select locales to enable  (SPACE = toggle, ENTER = confirm)\nen_US is pre-selected and strongly recommended." \
                16 72 3 \
                "en_US" "en_US.UTF-8 UTF-8  (English US)" "on" \
                "ja_JP" "ja_JP.UTF-8 UTF-8  (Japanese)"   "off" \
                "es_PE" "es_PE.UTF-8 UTF-8  (Spanish Peru)" "off" || continue 2

            mapfile -t raw_locales <<<"$DIALOG_OUT"
            # Filter empty lines
            local cleaned=()
            for l in "${raw_locales[@]}"; do [[ -n "$l" ]] && cleaned+=("$l"); done
            raw_locales=("${cleaned[@]}")

            if [[ ${#raw_locales[@]} -eq 0 ]]; then
                run_dialog --title "!!" --msgbox "$DT_ATLEAST1" 7 62
            else
                break
            fi
        done

        # Map tags to full locale strings
        SELECTED_LOCALES=()
        for tag in "${raw_locales[@]}"; do
            [[ -n "${LOCALE_MAP[$tag]+x}" ]] && SELECTED_LOCALES+=("${LOCALE_MAP[$tag]}")
        done

        # ── Keyboard layout ───────────────────────────────────────────────────
        run_dialog --title "Keyboard Layout" \
            --menu "Select your keyboard layout:" \
            12 56 3 \
            "us"    "English (US)  — KEYMAP=us" \
            "es"    "Spanish       — KEYMAP=es" \
            "jp106" "Japanese 106  — KEYMAP=jp106" || continue
        SELECTED_KEYMAP="$DIALOG_OUT"

        # ── Summary ───────────────────────────────────────────────────────────
        local locale_display
        locale_display=$(printf '  • %s\n' "${SELECTED_LOCALES[@]}")
        run_dialog --title "Locale & Keyboard — look right?" \
            --yesno "Locales:\n${locale_display}\n\nKeyboard: ${SELECTED_KEYMAP}\n\nTimezone: America/Lima (hardcoded, sorry not sorry)" \
            14 66 && return 0
    done
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 5 — Misc, Drivers & Optional Packages
# ═════════════════════════════════════════════════════════════════════════════
section_5() {
    while true; do
        # yay
        if run_dialog --title "yay (AUR helper)" \
               --yesno "Install yay (AUR helper)?\nHighly recommended unless you enjoy suffering." 8 60; then
            INSTALL_YAY=true
        else
            INSTALL_YAY=false
            clear; t_noyay; sleep 1
        fi

        # SDDM
        if run_dialog --title "SDDM (Display Manager)" \
               --yesno "Install and enable SDDM?\n(Login screen / display manager)" 8 60; then
            INSTALL_SDDM=true
        else
            INSTALL_SDDM=false
            clear; t_nosddm; sleep 1
        fi

        # GPU
        run_dialog --title "GPU Drivers" \
            --menu "What's your GPU situation?" \
            15 66 5 \
            "intel"  "Intel integrated — mesa, vulkan-intel, etc." \
            "rtx"    "NVIDIA RTX       — (not implemented yet, just noted)" \
            "gtx"    "NVIDIA GTX       — (not implemented yet, just noted)" \
            "athlon" "AMD/Athlon       — (not implemented yet, just noted)" \
            "broke"  "None / I'll handle drivers myself" || continue
        GPU_TYPE="$DIALOG_OUT"
        if [[ "$GPU_TYPE" == "broke" ]]; then clear; t_broke; sleep 1; fi

        # OS detection
        if run_dialog --title "Detect Other OSes" \
               --defaultno \
               --yesno "Enable os-prober to detect other operating systems in GRUB?\n(Useful for dual-boot setups)" 9 64; then
            DETECT_OS=true
        else
            DETECT_OS=false
            clear; t_nobios; sleep 1
        fi

        # Autologin
        if run_dialog --title "Autologin" \
               --defaultno \
               --yesno "Set up autologin for '${INPUT_USERNAME}'?\n(Logs in automatically on boot, no password prompt)" 9 64; then
            AUTOLOGIN=true
        else
            AUTOLOGIN=false
            clear; t_noautologin; sleep 1
        fi

        # Optional packages checklist
        OPTIONAL_PACKAGES=()
        run_dialog --title "Optional Packages" \
            --separate-output \
            --checklist "Select extra packages to install  (SPACE = toggle)\nAll optional — select nothing if you hate nice things." \
            18 70 6 \
            "firefox"  "Firefox web browser"                   "off" \
            "code"     "VS Code (open source build)"           "off" \
            "dolphin"  "Dolphin file manager (KDE)"            "off" \
            "kitty"    "Kitty GPU terminal emulator"           "off" \
            "fonts"    "Basic dev fonts (Hack/JetBrains/NF)"  "off" || continue

        if [[ -n "$DIALOG_OUT" ]]; then
            while IFS= read -r pkg; do
                [[ -n "$pkg" ]] && OPTIONAL_PACKAGES+=("$pkg")
            done <<<"$DIALOG_OUT"
        else
            clear; t_nopkgs; sleep 1
        fi

        # ── Summary ───────────────────────────────────────────────────────────
        local yay_str;    $INSTALL_YAY  && yay_str="yes"  || yay_str="no"
        local sddm_str;   $INSTALL_SDDM && sddm_str="yes" || sddm_str="no"
        local os_str;     $DETECT_OS    && os_str="yes"   || os_str="no"
        local auto_str;   $AUTOLOGIN    && auto_str="yes"  || auto_str="no"
        local pkg_str;    [[ ${#OPTIONAL_PACKAGES[@]} -gt 0 ]] \
                            && pkg_str=$(printf '%s ' "${OPTIONAL_PACKAGES[@]}") \
                            || pkg_str="(none)"

        run_dialog --title "Section 5 Summary — look right?" \
            --yesno "yay:              ${yay_str}\nSDDM:             ${sddm_str}\nGPU:              ${GPU_TYPE}\nDetect other OS:  ${os_str}\nAutologin:        ${auto_str}\nExtra packages:   ${pkg_str}" \
            14 66 && return 0
    done
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 6 — Grand Summary & Final Retry Opportunity
# ═════════════════════════════════════════════════════════════════════════════
do_punishment_gate() {
    # Returns 0 if punishment passed (allow retry), 1 if user gave up
    local str="${PUNISH_STRINGS[$PUNISH_IDX]}"
    PUNISH_IDX=$(( (PUNISH_IDX + 1) % ${#PUNISH_STRINGS[@]} ))

    while true; do
        run_dialog --title "Retry Request — Type EXACTLY:" \
            --inputbox "...so you messed up. i'll allow a retry, BUT.\nYou must type this string EXACTLY (case sensitive):\n\n\"${str}\"" \
            12 74 || return 1

        if [[ "$DIALOG_OUT" == "$str" ]]; then
            run_dialog --title "...fine." --msgbox "$DT_PUNISH_OK" 7 60
            return 0
        else
            run_dialog --title "WRONG." \
                --msgbox "$DT_PUNISH_FAIL" 8 60
            run_dialog --title "Now what?" \
                --menu "" 8 52 2 \
                "retry"  "Let me try typing it again" \
                "forget" "Forget it, back to summary" || return 1
            [[ "$DIALOG_OUT" == "forget" ]] && return 1
        fi
    done
}

section_6() {
    while true; do
        # ── Build big summary ─────────────────────────────────────────────────
        local swap_line yay_s sddm_s os_s auto_s root_s locale_s pkg_s

        $USE_SWAP    && swap_line="SWAP:               /dev/${INPUT_SWAP}" \
                     || swap_line="SWAP:               (none)"
        $INSTALL_YAY  && yay_s="yes"  || yay_s="no"
        $INSTALL_SDDM && sddm_s="yes" || sddm_s="no"
        $DETECT_OS    && os_s="yes"   || os_s="no"
        $AUTOLOGIN    && auto_s="yes"  || auto_s="no"
        $ROOT_ENABLED && root_s="enabled" || root_s="disabled (locked)"
        locale_s=$(printf '%s  ' "${SELECTED_LOCALES[@]}")
        [[ ${#OPTIONAL_PACKAGES[@]} -gt 0 ]] \
            && pkg_s=$(printf '%s ' "${OPTIONAL_PACKAGES[@]}") \
            || pkg_s="(none)"

        local lsblk_out
        lsblk_out=$(lsblk)

        local summary
        summary="── DRIVES ──────────────────────────────────
Parent Drive:       /dev/${INPUT_PARENT}
EFI:                /dev/${INPUT_EFI}
${swap_line}
Filesystem:         /dev/${INPUT_FILESYSTEM}

── SYSTEM ──────────────────────────────────
Hostname:           ${INPUT_SYSTEMNAME}
Username:           ${INPUT_USERNAME}
Password:           ********
Root account:       ${root_s}

── LOCALE & KEYBOARD ───────────────────────
Locales:            ${locale_s}
Keymap:             ${SELECTED_KEYMAP}
Timezone:           America/Lima (hardcoded)

── EXTRAS ──────────────────────────────────
yay:                ${yay_s}
SDDM:               ${sddm_s}
GPU drivers:        ${GPU_TYPE}
Detect other OSes:  ${os_s}
Autologin:          ${auto_s}
Extra packages:     ${pkg_s}

── DISK LAYOUT ─────────────────────────────
${lsblk_out}"

        run_dialog --title "FULL SUMMARY — everything will be wiped. no take-backs." \
            --menu "$summary" \
            40 80 6 \
            "go"   "Let's GO. start the install." \
            "s2"   "Retry Section 2 (system/user/password)" \
            "s3"   "Retry Section 3 (root account)" \
            "s4"   "Retry Section 4 (locale/keyboard)" \
            "s5"   "Retry Section 5 (extras & packages)" \
            "s1"   "Retry Section 1 (drive/partitions)" || continue

        case "$DIALOG_OUT" in
            go) break ;;
            s1) do_punishment_gate && section_1 ;;
            s2) do_punishment_gate && section_2 ;;
            s3) do_punishment_gate && section_3 ;;
            s4) do_punishment_gate && section_4 ;;
            s5) do_punishment_gate && section_5 ;;
        esac
    done
}

# ═════════════════════════════════════════════════════════════════════════════
# INSTALLATION — format, mount, pacstrap, genfstab
# ═════════════════════════════════════════════════════════════════════════════
do_install() {
    clear
    echo -e "${B}${CY}══ INSTALLATION STARTING — fingers crossed ══${R}\n"

    echo "Formatting..."
    mkfs.ext4 "/dev/$INPUT_FILESYSTEM"
    mkfs.fat -F 32 "/dev/$INPUT_EFI"
    if $USE_SWAP; then
        mkswap "/dev/$INPUT_SWAP"
    fi

    echo "Mounting..."
    mount "/dev/$INPUT_FILESYSTEM" /mnt
    mkdir -p /mnt/boot/efi
    mount "/dev/$INPUT_EFI" /mnt/boot/efi
    if $USE_SWAP; then
        swapon "/dev/$INPUT_SWAP"
    fi

    echo ""
    echo "Final disk layout:"
    lsblk
    echo ""

    echo "Pacstrapping... (this is the slow part, go get a snack)"
    pacstrap /mnt base linux linux-firmware sof-firmware base-devel \
        git grub efibootmgr nano networkmanager os-prober 2>&1

    echo "Generating fstab..."
    genfstab -U /mnt > /mnt/etc/fstab

    create_secondary_script
    echo ""
    echo -e "${B}${CY}Entering chroot — handing off to second script...${R}"
    arch-chroot /mnt /bin/bash /install_pt2.sh

    # ── Final rundown (back in live ISO context) ──────────────────────────────
    clear
    echo -e "${B}${CY}╔══════════════════════════════════════════╗"
    echo    "║   INSTALLATION COMPLETE — FINAL REPORT  ║"
    echo -e "╚══════════════════════════════════════════╝${R}"
    echo ""

    if [[ -f /mnt/var/log/osean_install.log ]]; then
        local errs
        errs=$(cat /mnt/var/log/osean_install.log)
        if [[ -n "$errs" ]]; then
            echo -e "${RD}${B}Things that did not go as planned:${R}"
            echo "$errs"
            echo ""
            echo -e "${YL}check the above before rebooting, baka.${R}"
        else
            echo -e "${GR}${B}Everything went perfectly. Not that I'm impressed or anything.${R}"
        fi
    else
        echo -e "${GR}${B}No errors logged. we're good.${R}"
    fi

    echo ""
    echo -e "${MG}${B}You can now reboot. Type:  reboot${R}"
    echo -e "${YL}...and don't break this one too. i mean it. baka.${R}\n"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECONDARY SCRIPT — runs inside the chroot via arch-chroot
# Variables are expanded NOW (heredoc without quoted delimiter) so all user
# choices are baked directly into the script.
# ═════════════════════════════════════════════════════════════════════════════
create_secondary_script() {
    # Serialize arrays into newline-delimited strings for the script
    local locales_str
    locales_str=$(printf '%s\n' "${SELECTED_LOCALES[@]}")
    local pkgs_str
    pkgs_str=$(printf '%s\n' "${OPTIONAL_PACKAGES[@]}")

    # Resolve "fonts" package tag to actual package names
    local font_pkgs="ttf-hack ttf-dejavu ttf-jetbrains-mono ttf-nerd-fonts-symbols"

    cat > /mnt/install_pt2.sh <<ENDOFSCRIPT
#!/bin/bash
# Secondary install script — runs inside arch-chroot
# Auto-generated by Osean's Arch Installer. Will self-delete at end.

LOG=/var/log/osean_install.log
> "\$LOG"

log_err() { echo "[ERROR] \$*" | tee -a "\$LOG"; }
log_ok()  { echo "[ok]    \$*"; }

echo ""
echo "=== LOCALE, TIME, HOSTNAME ==="

# Timezone
ln -sf /usr/share/zoneinfo/America/Lima /etc/localtime
hwclock --systohc
log_ok "Timezone set to America/Lima"

# Uncomment selected locales in locale.gen
while IFS= read -r locale; do
    [[ -z "\$locale" ]] && continue
    if grep -q "^#\${locale}\$" /etc/locale.gen; then
        sed -i "s|^#\${locale}\$|\${locale}|" /etc/locale.gen
        log_ok "Locale enabled: \${locale}"
    elif grep -q "^\${locale}\$" /etc/locale.gen; then
        log_ok "Locale already enabled: \${locale}"
    else
        log_err "Could not find locale to uncomment: \${locale}"
    fi
done <<'LOCALES'
${locales_str}
LOCALES

locale-gen

# Set LANG based on first locale
FIRST_LOCALE=$(echo "${locales_str}" | head -1 | awk '{print $1}')
echo "LANG=\${FIRST_LOCALE}" > /etc/locale.conf

# Keymap
echo "KEYMAP=${SELECTED_KEYMAP}" > /etc/vconsole.conf
log_ok "Keymap set to ${SELECTED_KEYMAP}"

# Hostname
echo "${INPUT_SYSTEMNAME}" > /etc/hostname
log_ok "Hostname set to ${INPUT_SYSTEMNAME}"

echo ""
echo "=== USER & SUDO ==="

# Create user
useradd -m -G wheel -s /bin/bash "${INPUT_USERNAME}"
echo "${INPUT_USERNAME}:${INPUT_PASSWORD}" | chpasswd
log_ok "User '${INPUT_USERNAME}' created"

# Root account
if [[ "${ROOT_ENABLED}" == "true" ]]; then
    echo "root:${ROOT_PASSWORD}" | chpasswd
    log_ok "Root account enabled and password set"
else
    passwd -l root
    log_ok "Root account locked"
fi

# Uncomment wheel in sudoers
if sed -i 's/^# %wheel ALL=(ALL:ALL) ALL$/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers; then
    log_ok "Wheel group sudoers rule enabled"
else
    log_err "Could not uncomment wheel rule in sudoers — check manually!"
fi

echo ""
echo "=== MULTILIB ==="

# Enable [multilib] in pacman.conf
if sed -i 's/^#\[multilib\]/[multilib]/' /etc/pacman.conf && \
   sed -i '/^\[multilib\]/{n;s/^#Include/Include/}' /etc/pacman.conf; then
    log_ok "multilib enabled in pacman.conf"
else
    log_err "Could not enable multilib — check pacman.conf manually"
fi

echo ""
echo "=== GRUB ==="

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB 2>>/var/log/osean_install.log \
    || grub-install "/dev/${INPUT_PARENT}" 2>>/var/log/osean_install.log \
    || log_err "GRUB install failed! Check the log."

# os-prober
if [[ "${DETECT_OS}" == "true" ]]; then
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=false\$/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub || true
    DISK=\$(lsblk -no PKNAME \$(findmnt -n -o SOURCE /) 2>/dev/null || echo "")
    if [[ -n "\$DISK" ]]; then
        for p in /dev/\${DISK}*; do
            sudo mkdir -p /mnt/\$(basename "\$p")
            sudo mount "\$p" /mnt/\$(basename "\$p") 2>/dev/null || true
        done
    fi
    log_ok "os-prober configured"
fi

grub-mkconfig -o /boot/grub/grub.cfg 2>>/var/log/osean_install.log \
    && log_ok "GRUB config generated" \
    || log_err "grub-mkconfig failed — check manually"

echo ""
echo "=== NETWORK ==="

systemctl enable NetworkManager
log_ok "NetworkManager enabled"

pacman -Syu --noconfirm 2>>/var/log/osean_install.log \
    && log_ok "System fully updated" \
    || log_err "pacman -Syu had issues — check the log"

echo ""
echo "=== EXTRAS ==="

# SDDM
if [[ "${INSTALL_SDDM}" == "true" ]]; then
    pacman -S --needed --noconfirm sddm 2>>/var/log/osean_install.log \
        && systemctl enable sddm \
        && log_ok "SDDM installed and enabled" \
        || log_err "SDDM installation failed"
fi

# GPU drivers
case "${GPU_TYPE}" in
    intel)
        pacman -S --needed --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel \
            2>>/var/log/osean_install.log \
            && log_ok "Intel GPU drivers installed" \
            || log_err "Intel GPU driver install had issues"
        ;;
    rtx|gtx|athlon)
        log_err "GPU type '${GPU_TYPE}' selected but driver installation not yet implemented in this script — install drivers manually after boot."
        ;;
    broke|*)
        log_ok "No GPU drivers requested"
        ;;
esac

# Autologin
if [[ "${AUTOLOGIN}" == "true" ]]; then
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null <<AUTOEOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${INPUT_USERNAME} --noclear %I \$TERM
AUTOEOF
    log_ok "Autologin configured for ${INPUT_USERNAME}"
fi

# yay (must be installed as user, not root)
if [[ "${INSTALL_YAY}" == "true" ]]; then
    su - "${INPUT_USERNAME}" -c "
        git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin 2>/dev/null &&
        cd /tmp/yay-bin &&
        makepkg -si --noconfirm 2>/dev/null
    " && log_ok "yay installed" || log_err "yay installation failed — install manually after boot"
fi

# Optional packages (resolve 'fonts' tag)
declare -A PKG_MAP=(
    ["firefox"]="firefox"
    ["code"]="code"
    ["dolphin"]="dolphin"
    ["kitty"]="kitty"
    ["fonts"]="${font_pkgs}"
)

PKGS_TO_INSTALL=""
while IFS= read -r pkg; do
    [[ -z "\$pkg" ]] && continue
    resolved="\${PKG_MAP[\$pkg]:-\$pkg}"
    PKGS_TO_INSTALL="\${PKGS_TO_INSTALL} \${resolved}"
done <<'PKGLIST'
${pkgs_str}
PKGLIST

if [[ -n "\${PKGS_TO_INSTALL// /}" ]]; then
    # shellcheck disable=SC2086
    pacman -S --needed --noconfirm \$PKGS_TO_INSTALL 2>>/var/log/osean_install.log \
        && log_ok "Optional packages installed: \${PKGS_TO_INSTALL}" \
        || log_err "Some optional packages failed to install — check the log"
fi

echo ""
echo "=== DONE ==="
echo "Secondary script finished. Cleaning up..."

# Self-destruct
rm -f /install_pt2.sh
ENDOFSCRIPT

    chmod +x /mnt/install_pt2.sh
}

# ═════════════════════════════════════════════════════════════════════════════
# MAIN
# ═════════════════════════════════════════════════════════════════════════════
main() {
    clear

    check_network
    setup_tools

    clear
    echo -e "${MG}${B}"
    echo "  ╔═══════════════════════════════════════════════════╗"
    echo "  ║    Osean's Arch Install Script — Tsundere v2     ║"
    echo -e "  ╚═══════════════════════════════════════════════════╝${R}"
    echo ""
    t_reinstall
    echo ""
    echo -e "${CY}Press Enter to begin...${R}"
    read -r

    section_1
    section_2
    section_3
    section_4
    section_5
    section_6
    do_install
}

main