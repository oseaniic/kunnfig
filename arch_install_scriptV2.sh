#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║   Osean's Arch Install Script — Remastered                  ║
# ║   "W-What?! You're reinstalling AGAIN?! How many times      ║
# ║    did you break it this time, BAKAAAA!"                    ║
# ╚══════════════════════════════════════════════════════════════╝

# ── Hard abort on Ctrl-C ────────────────────────────────────────
trap '
    tput cnorm 2>/dev/null
    echo -e "\n\n\033[1;33mFine! Just leave mid-install! See if I care!\n...Hmph. Baka.\033[0m\n"
    exit 130
' INT TERM

# ── Environment ─────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/arch_install_$(date +%Y%m%d_%H%M%S).log"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; B='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ── Logging ─────────────────────────────────────────────────────
_ts()     { date '+%H:%M:%S'; }
log()     { printf '[%s] %s\n'             "$(_ts)" "$*" >> "$LOG_FILE"; }
log_h()   { printf '\n[%s] ════ %s ════\n' "$(_ts)" "$*" >> "$LOG_FILE"; }
log_ok()  { printf '[%s] ✓ %s\n'           "$(_ts)" "$*" >> "$LOG_FILE"; }
log_err() { printf '[%s] ✗ ERROR: %s\n'    "$(_ts)" "$*" >> "$LOG_FILE"; }

run() {
    log "CMD: $*"
    "$@" 2>&1 | tee -a "$LOG_FILE"
    local rc=${PIPESTATUS[0]}
    if [ $rc -ne 0 ]; then log_err "Failed (rc=$rc): $*"; else log_ok "Done: $*"; fi
    return $rc
}

printf '╔══════════════════════════════════════════╗\n'      >> "$LOG_FILE"
printf '║  Arch Install Log — %s  ║\n' "$(date '+%Y-%m-%d %H:%M')" >> "$LOG_FILE"
printf '╚══════════════════════════════════════════╝\n\n'    >> "$LOG_FILE"
log "Script: $SCRIPT_DIR"
log "Log   : $LOG_FILE"

# ── h_menu: horizontal arrow-key menu ───────────────────────────
# h_menu RESULT_VAR DEFAULT_IDX "opt1" "opt2" ...
h_menu() {
    local -n _hr=$1; local _hd=$2; shift 2
    local -a _ho=("$@"); local _hs=$_hd; local _ht=${#_ho[@]}
    local _hk _hk2 _hi

    tput civis
    echo -ne "\r\033[2K  "
    for _hi in "${!_ho[@]}"; do
        [ $_hi -eq $_hs ] \
            && printf '\e[1;7m  %s  \e[0m ' "${_ho[$_hi]}" \
            || printf '  %s  ' "${_ho[$_hi]}"
    done

    while true; do
        IFS= read -rsn1 _hk
        if [[ $_hk == $'\x1b' ]]; then
            read -rsn2 -t 0.1 _hk2
            case $_hk2 in
                '[D') ((_hs--)); [ $_hs -lt 0 ] && _hs=$((_ht-1)) ;;
                '[C') ((_hs++)); [ $_hs -ge $_ht ] && _hs=0 ;;
                *) continue ;;
            esac
        elif [[ $_hk == '' ]]; then break
        else continue; fi
        echo -ne "\r\033[2K  "
        for _hi in "${!_ho[@]}"; do
            [ $_hi -eq $_hs ] \
                && printf '\e[1;7m  %s  \e[0m ' "${_ho[$_hi]}" \
                || printf '  %s  ' "${_ho[$_hi]}"
        done
    done
    tput cnorm; echo ""; _hr=${_ho[$_hs]}
}

# ── v_menu: vertical arrow-key menu ─────────────────────────────
# v_menu RESULT_VAR DEFAULT_IDX "opt1" "opt2" ...
v_menu() {
    local -n _vr=$1; local _vd=$2; shift 2
    local -a _vo=("$@"); local _vs=$_vd; local _vt=${#_vo[@]}
    local _vk _vk2 _vi

    tput civis
    for _vi in "${!_vo[@]}"; do
        [ $_vi -eq $_vs ] \
            && printf '  \e[1;7m %-52s \e[0m\n' "${_vo[$_vi]}" \
            || printf '    %-52s  \n'            "${_vo[$_vi]}"
    done

    while true; do
        IFS= read -rsn1 _vk
        if [[ $_vk == $'\x1b' ]]; then
            read -rsn2 -t 0.1 _vk2
            case $_vk2 in
                '[A') ((_vs--)); [ $_vs -lt 0 ] && _vs=$((_vt-1)) ;;
                '[B') ((_vs++)); [ $_vs -ge $_vt ] && _vs=0 ;;
                *) continue ;;
            esac
        elif [[ $_vk == '' ]]; then break
        else continue; fi
        tput cuu $_vt
        for _vi in "${!_vo[@]}"; do
            [ $_vi -eq $_vs ] \
                && printf '  \e[1;7m %-52s \e[0m\n' "${_vo[$_vi]}" \
                || printf '    %-52s  \n'            "${_vo[$_vi]}"
        done
    done
    tput cnorm; _vr=${_vo[$_vs]}
}

# ── cb_menu: checkbox menu ───────────────────────────────────────
# cb_menu RESULT_ARR "0,1,..." "opt1" ... "Continue"
# Space or Enter toggles item; Enter on "Continue" confirms.
cb_menu() {
    local -n _cr=$1; local _cd=$2; shift 2
    local -a _co=("$@"); local _cs=0; local _ct=${#_co[@]}
    local _ck _ck2 _ci _changed _m
    local -a _cc

    for _ci in "${!_co[@]}"; do _cc[$_ci]=0; done
    if [ -n "$_cd" ]; then
        IFS=',' read -ra _cda <<< "$_cd"
        for _d in "${_cda[@]}"; do [[ $_d =~ ^[0-9]+$ ]] && _cc[$_d]=1; done
    fi

    tput civis
    # Initial draw
    for _ci in "${!_co[@]}"; do
        if   [ "${_co[$_ci]}" = "Continue" ]; then _m=" ──▶"
        elif [ "${_cc[$_ci]}" -eq 1 ];         then _m=" [x]"
        else                                         _m=" [ ]"; fi
        [ $_ci -eq $_cs ] \
            && printf '  \e[1;7m%s  %-44s\e[0m\n' "$_m" "${_co[$_ci]}" \
            || printf '  %s  %-44s\n'              "$_m" "${_co[$_ci]}"
    done

    while true; do
        IFS= read -rsn1 _ck; _changed=0
        if [[ $_ck == $'\x1b' ]]; then
            read -rsn2 -t 0.1 _ck2
            case $_ck2 in
                '[A') ((_cs--)); [ $_cs -lt 0 ] && _cs=$((_ct-1)); _changed=1 ;;
                '[B') ((_cs++)); [ $_cs -ge $_ct ] && _cs=0; _changed=1 ;;
            esac
        elif [[ $_ck == ' ' ]]; then
            [ "${_co[$_cs]}" != "Continue" ] && { _cc[$_cs]=$(( 1 - _cc[$_cs] )); _changed=1; }
        elif [[ $_ck == '' ]]; then
            if [ "${_co[$_cs]}" = "Continue" ]; then break
            else _cc[$_cs]=$(( 1 - _cc[$_cs] )); _changed=1; fi
        fi
        if [ $_changed -eq 1 ]; then
            tput cuu $_ct
            for _ci in "${!_co[@]}"; do
                if   [ "${_co[$_ci]}" = "Continue" ]; then _m=" ──▶"
                elif [ "${_cc[$_ci]}" -eq 1 ];         then _m=" [x]"
                else                                         _m=" [ ]"; fi
                [ $_ci -eq $_cs ] \
                    && printf '  \e[1;7m%s  %-44s\e[0m\n' "$_m" "${_co[$_ci]}" \
                    || printf '  %s  %-44s\n'              "$_m" "${_co[$_ci]}"
            done
        fi
    done
    tput cnorm
    _cr=()
    for _ci in "${!_co[@]}"; do
        [ "${_co[$_ci]}" != "Continue" ] && [ "${_cc[$_ci]}" -eq 1 ] && _cr+=("${_co[$_ci]}")
    done
}

# ════════════════════════════════════════════════════════════════
#  SECTION 1 — Drive & Partition Selection
# ════════════════════════════════════════════════════════════════
section_1() {
    log_h "SECTION 1: Drive & Partition Selection"
    local _drive_choice _action _efi_choice _swap_choice _fs_choice _confirm
    local -a _drives _parts

    while true; do  # outer loop: full redo
        # ── Pick drive ────────────────────────────────────────────
        while true; do  # inner loop: drive pick + manage
            clear
            echo -e "${B}Current disk layout:${NC}"
            lsblk
            echo ""
            echo -e "${Y}Select your target drive:${NC}"
            mapfile -t _drives < <(lsblk -dn -o NAME --sort NAME)
            v_menu SEL_DRIVE 0 "${_drives[@]}"
            echo ""
            log "Drive selected: $SEL_DRIVE"

            # ── Partitions for that drive ──────────────────────────
            while true; do
                clear
                echo -e "${B}Drive: /dev/$SEL_DRIVE${NC}"
                lsblk "/dev/$SEL_DRIVE"
                echo ""
                echo -e "${Y}What would you like to do?${NC}"
                h_menu _action 0 "Continue" "Manage Partitions" "Different Drive"

                if   [ "$_action" = "Continue" ];           then break 2
                elif [ "$_action" = "Manage Partitions" ];  then
                    cfdisk "/dev/$SEL_DRIVE"; clear
                elif [ "$_action" = "Different Drive" ];     then break  # re-pick drive
                fi
            done
        done

        # ── Pick EFI ──────────────────────────────────────────────
        mapfile -t _parts < <(
            lsblk -ln -o NAME,SIZE,FSTYPE,TYPE "/dev/$SEL_DRIVE" \
            | awk '$4=="part"{fs=($3==""?"raw":$3); printf "%s  (%s  %s)\n",$1,$2,fs}'
        )
        if [ ${#_parts[@]} -eq 0 ]; then
            echo -e "${R}No partitions found on /dev/$SEL_DRIVE. Please create them first!${NC}"
            read -rsn1; continue
        fi

        clear
        echo -e "${B}Drive: /dev/$SEL_DRIVE${NC}"
        lsblk "/dev/$SEL_DRIVE"
        echo ""
        echo -e "${Y}Select the ${B}EFI${NC}${Y} partition  ${DIM}(recommended: 100–300 MB, will be formatted FAT32)${NC}"
        v_menu _efi_choice 0 "${_parts[@]}"
        SEL_EFI=$(echo "$_efi_choice" | awk '{print $1}')
        log "EFI partition: $SEL_EFI"

        # ── SWAP ──────────────────────────────────────────────────
        clear
        echo -e "${Y}Do you want a SWAP partition?  ${DIM}(optional on modern systems with plenty of RAM)${NC}"
        h_menu _swap_yn 0 "Yes" "No"
        if [ "$_swap_yn" = "Yes" ]; then
            USE_SWAP=1
            local -a _noEFI=()
            for p in "${_parts[@]}"; do
                [[ "$p" != ${SEL_EFI}* ]] && _noEFI+=("$p")
            done
            echo ""
            echo -e "${Y}Select the ${B}SWAP${NC}${Y} partition  ${DIM}(recommended: 4–8 GB)${NC}"
            v_menu _swap_choice 0 "${_noEFI[@]}"
            SEL_SWAP=$(echo "$_swap_choice" | awk '{print $1}')
            log "Swap partition: $SEL_SWAP"
        else
            USE_SWAP=0; SEL_SWAP=""
            echo -e "${DIM}No swap. Living dangerously, I see.${NC}"
        fi

        # ── Pick Filesystem ───────────────────────────────────────
        local -a _noEFI_noSWAP=()
        for p in "${_parts[@]}"; do
            [[ "$p" != ${SEL_EFI}* ]] && [[ -z "$SEL_SWAP" || "$p" != ${SEL_SWAP}* ]] && _noEFI_noSWAP+=("$p")
        done
        echo ""
        echo -e "${Y}Select the ${B}Filesystem${NC}${Y} partition  ${DIM}(30G bare, 50G standard, 80G recommended, 150G+ heavy use)${NC}"
        v_menu _fs_choice 0 "${_noEFI_noSWAP[@]}"
        SEL_FS=$(echo "$_fs_choice" | awk '{print $1}')
        log "Filesystem partition: $SEL_FS"

        # ── Section 1 confirm ─────────────────────────────────────
        clear
        echo -e "${B}════ Partition Summary ════${NC}"
        echo -e "  Drive      : ${C}/dev/$SEL_DRIVE${NC}"
        echo -e "  EFI        : ${C}/dev/$SEL_EFI${NC}"
        echo -e "  Swap       : ${C}$([ $USE_SWAP -eq 1 ] && echo "/dev/$SEL_SWAP" || echo "none")${NC}"
        echo -e "  Filesystem : ${C}/dev/$SEL_FS${NC}"
        echo ""
        lsblk
        echo ""
        echo -e "${Y}Does this look correct?${NC}"
        h_menu _confirm 0 "Looks good, continue!" "Start over"
        [ "$_confirm" = "Looks good, continue!" ] && break
        log "User chose to redo section 1"
    done
    log "Section 1 complete — drive=$SEL_DRIVE efi=$SEL_EFI swap=$SEL_SWAP fs=$SEL_FS"
}

# ════════════════════════════════════════════════════════════════
#  SECTION 2 — System Name, User & Password
# ════════════════════════════════════════════════════════════════
section_2() {
    log_h "SECTION 2: User Details"
    local _confirm _test_pw _typed

    while true; do
        clear
        echo -e "${B}════ Section 2: Account Setup ════${NC}\n"

        # System name
        while true; do
            echo -ne "${Y}System hostname: ${NC}"; read -r SYS_NAME
            [[ "$SYS_NAME" =~ ^[a-zA-Z0-9_-]+$ ]] && break
            echo -e "${R}Invalid hostname. Letters, numbers, hyphens, underscores only.${NC}"
        done

        # Username
        while true; do
            echo -ne "${Y}Username (lowercase only): ${NC}"; read -r USERNAME
            [[ "$USERNAME" =~ ^[a-z][a-z0-9_-]*$ ]] && break
            echo -e "${R}Invalid. Must start with a letter; lowercase letters/numbers/underscores/hyphens only.${NC}"
        done

        # Password
        while true; do
            while true; do
                echo -ne "${Y}Password: ${NC}"; read -rs USER_PASS; echo ""
                [ -n "$USER_PASS" ] && break
                echo -e "${R}Empty password? Really?! No.${NC}"
            done
            echo -ne "${Y}Confirm password: ${NC}"; read -rs _pw2; echo ""
            [ "$USER_PASS" = "$_pw2" ] && break
            echo -e "${R}Passwords don't match. Try again, genius.${NC}"
        done

        # Confirm screen
        while true; do
            clear
            echo -e "${B}════ Account Summary ════${NC}"
            echo -e "  Hostname : ${C}$SYS_NAME${NC}"
            echo -e "  Username : ${C}$USERNAME${NC}"
            echo -e "  Password : ${C}$(printf '%0.s*' $(seq 1 ${#USER_PASS}))${NC}"
            echo ""
            echo -e "${Y}Does this look right?${NC}"
            h_menu _confirm 0 "Yes, continue" "Retry" "Test my password"

            if   [ "$_confirm" = "Yes, continue" ]; then break 2
            elif [ "$_confirm" = "Retry" ]; then break  # redo the inputs
            elif [ "$_confirm" = "Test my password" ]; then
                echo -ne "${Y}Type your password to test it: ${NC}"; read -rs _typed; echo ""
                if [ "$_typed" = "$USER_PASS" ]; then
                    echo -e "${G}✓ Password matches! Good job not breaking that too.${NC}"
                else
                    echo -e "${R}✗ Nope. That's wrong. How did you fail twice?${NC}"
                fi
                sleep 2
            fi
        done
    done
    log "Section 2 complete — hostname=$SYS_NAME username=$USERNAME"
}

# ════════════════════════════════════════════════════════════════
#  SECTION 3 — Root / Administrator Account
# ════════════════════════════════════════════════════════════════
section_3() {
    log_h "SECTION 3: Root Account"
    local _yn _confirm

    clear
    echo -e "${B}════ Section 3: Administrator (root) Account ════${NC}\n"
    echo -e "${DIM}The root account is the system administrator. Most modern setups keep it"
    echo -e "locked and use sudo instead. Personally, I've never once needed it enabled."
    echo -e "Just saying.${NC}\n"
    echo -e "${Y}Enable the root account?${NC}"
    h_menu _yn 1 "Yes" "No (recommended)"

    USE_ROOT=0; ROOT_PASS=""

    if [ "$_yn" = "Yes" ]; then
        echo -e "${DIM}(Note: the root login username is just 'root'. No customization here.)${NC}\n"
        while true; do
            while true; do
                echo -ne "${Y}Root password: ${NC}"; read -rs ROOT_PASS; echo ""
                [ -n "$ROOT_PASS" ] && break
                echo -e "${R}Empty root password is a terrible idea. No.${NC}"
            done
            echo -ne "${Y}Confirm root password: ${NC}"; read -rs _rp2; echo ""
            if [ "$ROOT_PASS" != "$_rp2" ]; then
                echo -e "${R}Passwords don't match. Did you forget ALREADY?${NC}"
                continue
            fi

            if [ "$ROOT_PASS" = "$USER_PASS" ]; then
                echo -e "${Y}Yo, that's the same password as your regular user account, are you sure?${NC}"
                echo -e "${DIM}(Technically fine, but not recommended by Linux soy 250lb Redditors. Do whatever, I'm not your mom.)${NC}"
                h_menu _confirm 2 "Continue anyway" "Retry" "Nevermind (disable root)"
                if   [ "$_confirm" = "Continue anyway" ];     then USE_ROOT=1; break
                elif [ "$_confirm" = "Nevermind (disable root)" ]; then USE_ROOT=0; ROOT_PASS=""; break 2
                fi  # "Retry" loops
            else
                USE_ROOT=1; break
            fi
        done

        if [ $USE_ROOT -eq 1 ]; then
            echo -e "${G}Root account will be enabled.${NC}"
        fi
    else
        echo -e "${DIM}Smart choice. Root account will be locked.${NC}"
    fi

    sleep 1
    log "Section 3 complete — use_root=$USE_ROOT"
}

# ════════════════════════════════════════════════════════════════
#  SECTION 4 — Locale & Keyboard Layout
# ════════════════════════════════════════════════════════════════
section_4() {
    log_h "SECTION 4: Locale & Keyboard"
    local _confirm
    local -a _selected_locales

    while true; do
        clear
        echo -e "${B}════ Section 4: Locale & Keyboard ════${NC}\n"
        echo -e "${Y}Select your locale(s):  ${DIM}(↑↓ navigate, Space or Enter toggles, Enter on Continue confirms)${NC}"
        cb_menu _selected_locales "0" \
            "en_US.UTF-8 UTF-8" \
            "ja_JP.UTF-8 UTF-8" \
            "es_PE.UTF-8 UTF-8" \
            "Continue"

        if [ ${#_selected_locales[@]} -eq 0 ]; then
            echo -e "${R}You have to pick at least ONE locale, you absolute menace! Try again!!${NC}"
            sleep 2; continue
        fi

        LOCALES=("${_selected_locales[@]}")
        echo ""
        echo -e "${Y}Select your keyboard layout:${NC}"
        v_menu KEYMAP 0 "us  (QWERTY US)" "es  (Spanish)" "jp106  (Japanese 106)"

        # Strip to just the key (first word)
        KEYMAP=$(echo "$KEYMAP" | awk '{print $1}')

        # Confirm
        clear
        echo -e "${B}════ Locale Summary ════${NC}"
        echo -e "  Locales  : ${C}${LOCALES[*]}${NC}"
        echo -e "  Keymap   : ${C}$KEYMAP${NC}"
        echo -e "  Multilib : ${C}enabled (automatic)${NC}"
        echo ""
        echo -e "${Y}Does this look correct?${NC}"
        h_menu _confirm 0 "Yes, continue" "Redo this section"
        [ "$_confirm" = "Yes, continue" ] && break
        log "User redoing section 4"
    done
    log "Section 4 complete — locales=${LOCALES[*]} keymap=$KEYMAP"
}

# ════════════════════════════════════════════════════════════════
#  SECTION 5 — QoL Options & Extra Packages
# ════════════════════════════════════════════════════════════════
section_5() {
    log_h "SECTION 5: QoL & Extras"
    local _choice _confirm
    local -a _opt_pkgs_selected

    while true; do
        clear
        echo -e "${B}════ Section 5: Quality of Life Options ════${NC}\n"

        # yay
        echo -e "${Y}Install ${B}yay${NC}${Y} (AUR helper)?${NC}"
        h_menu _choice 0 "Yes (good idea)" "No (beta)"
        INSTALL_YAY=0
        if [ "$_choice" = "Yes (good idea)" ]; then
            INSTALL_YAY=1
        else
            echo -e "${DIM}...okay, beta.${NC}"; sleep 1
        fi

        # SDDM
        echo ""
        echo -e "${Y}Install & enable ${B}SDDM${NC}${Y} (display manager / login screen)?${NC}"
        h_menu _choice 0 "Yes" "No (soy)"
        INSTALL_SDDM=0
        if [ "$_choice" = "Yes" ]; then
            INSTALL_SDDM=1
        else
            echo -e "${DIM}Wow, no display manager. What are you, a 1990s sysadmin?${NC}"; sleep 1
        fi

        # GPU
        echo ""
        echo -e "${Y}What GPU do you have?  ${DIM}(RTX/GTX/AMD drivers are WIP, will be skipped if selected)${NC}"
        v_menu GPU_TYPE 4 \
            "intel boi  (mesa + intel drivers)" \
            "RTX boi    (not implemented yet, skipped)" \
            "GTX boi    (not implemented yet, skipped)" \
            "Athlon boi (not implemented yet, skipped)" \
            "broke boi  (no GPU drivers)"
        GPU_TYPE=$(echo "$GPU_TYPE" | awk '{print $1}')  # just "intel", "RTX", "GTX", "Athlon", "broke"

        # OS prober
        echo ""
        echo -e "${Y}Detect other operating systems via GRUB?  ${DIM}(e.g. Windows dual-boot)${NC}"
        h_menu _choice 0 "Yes" "No"
        DETECT_OS=0
        [ "$_choice" = "Yes" ] && DETECT_OS=1

        # Autologin
        echo ""
        echo -e "${Y}Set up ${B}autologin${NC}${Y} on TTY1?${NC}"
        h_menu _choice 1 "Yes" "No"
        AUTOLOGIN=0
        [ "$_choice" = "Yes" ] && AUTOLOGIN=1

        # Optional packages
        echo ""
        echo -e "${Y}Any extra packages?  ${DIM}(Space or Enter toggles, Enter on Continue confirms)${NC}"
        cb_menu _opt_pkgs_selected "" \
            "Firefox" \
            "Code (VS Code)" \
            "Dolphin (file manager)" \
            "Kitty (terminal)" \
            "Basic Fonts  (ttf-hack, ttf-dejavu, ttf-jetbrains-mono, nerd-fonts-symbols)" \
            "Continue"

        OPT_PKGS=("${_opt_pkgs_selected[@]}")

        if [ ${#OPT_PKGS[@]} -eq 0 ]; then
            echo -e "${DIM}K. That was the last time I do anything nice for you. Hmph.${NC}"; sleep 1
        fi

        # Confirm section 5
        clear
        echo -e "${B}════ Section 5 Summary ════${NC}"
        echo -e "  Install yay     : ${C}$([ $INSTALL_YAY  -eq 1 ] && echo yes || echo no)${NC}"
        echo -e "  Install SDDM    : ${C}$([ $INSTALL_SDDM -eq 1 ] && echo yes || echo no)${NC}"
        echo -e "  GPU Type        : ${C}$GPU_TYPE${NC}"
        echo -e "  Detect other OS : ${C}$([ $DETECT_OS -eq 1 ] && echo yes || echo no)${NC}"
        echo -e "  Autologin       : ${C}$([ $AUTOLOGIN -eq 1 ] && echo yes || echo no)${NC}"
        echo -e "  Extra packages  : ${C}$([ ${#OPT_PKGS[@]} -gt 0 ] && echo "${OPT_PKGS[*]}" || echo "none")${NC}"
        echo ""
        echo -e "${Y}Does this look right?${NC}"
        h_menu _confirm 0 "Yes, continue" "Redo this section"
        [ "$_confirm" = "Yes, continue" ] && break
        log "User redoing section 5"
    done
    log "Section 5 complete — yay=$INSTALL_YAY sddm=$INSTALL_SDDM gpu=$GPU_TYPE os_detect=$DETECT_OS autologin=$AUTOLOGIN pkgs=${OPT_PKGS[*]}"
}

# ════════════════════════════════════════════════════════════════
#  SECTION 6 — Final Rundown & Confirmation
# ════════════════════════════════════════════════════════════════
PUNISHMENT_STRINGS=(
    "I'm sorry boss, please allow me to retry."
    "I, a fool, beg to be allowed a second attempt."
    "My sincerest apologies for my pathetic configuration skills."
    "I humbly request the privilege of trying that again."
    "Please forgive this waste of disk space that I am."
    "I kneel before the terminal and implore a do-over."
    "My incompetence knows no bounds, yet I dare ask for mercy."
    "This unworthy user requests permission to redo the section."
    "I have brought shame to my partitions. Please let me retry."
    "Forgive me, for I have sinned against the filesystem."
)

section_6() {
    log_h "SECTION 6: Final Confirmation"
    local _choice _section _pstr _typed _punish_result

    while true; do
        clear
        echo -e "${B}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${B}║          FULL INSTALLATION SUMMARY               ║${NC}"
        echo -e "${B}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${B}── Partitions ──────────────────────────────────────${NC}"
        echo -e "  Drive       : ${C}/dev/$SEL_DRIVE${NC}"
        echo -e "  EFI         : ${C}/dev/$SEL_EFI${NC}"
        echo -e "  Swap        : ${C}$([ $USE_SWAP -eq 1 ] && echo "/dev/$SEL_SWAP" || echo "none")${NC}"
        echo -e "  Filesystem  : ${C}/dev/$SEL_FS${NC}"
        echo ""
        echo -e "${B}── Account ──────────────────────────────────────────${NC}"
        echo -e "  Hostname    : ${C}$SYS_NAME${NC}"
        echo -e "  Username    : ${C}$USERNAME${NC}"
        echo -e "  Password    : ${C}$(printf '%0.s*' $(seq 1 ${#USER_PASS}))${NC}"
        echo -e "  Root acct   : ${C}$([ $USE_ROOT -eq 1 ] && echo "enabled" || echo "locked")${NC}"
        echo ""
        echo -e "${B}── Locale & Input ───────────────────────────────────${NC}"
        echo -e "  Locales     : ${C}${LOCALES[*]}${NC}"
        echo -e "  Keymap      : ${C}$KEYMAP${NC}"
        echo -e "  Multilib    : ${C}enabled${NC}"
        echo -e "  Timezone    : ${C}America/Lima (hardcoded)${NC}"
        echo ""
        echo -e "${B}── Extras ───────────────────────────────────────────${NC}"
        echo -e "  Install yay : ${C}$([ $INSTALL_YAY  -eq 1 ] && echo yes || echo no)${NC}"
        echo -e "  SDDM        : ${C}$([ $INSTALL_SDDM -eq 1 ] && echo yes || echo no)${NC}"
        echo -e "  GPU type    : ${C}$GPU_TYPE${NC}"
        echo -e "  Detect OS   : ${C}$([ $DETECT_OS -eq 1 ] && echo yes || echo no)${NC}"
        echo -e "  Autologin   : ${C}$([ $AUTOLOGIN -eq 1 ] && echo yes || echo no)${NC}"
        echo -e "  Extra pkgs  : ${C}$([ ${#OPT_PKGS[@]} -gt 0 ] && echo "${OPT_PKGS[*]}" || echo "none")${NC}"
        echo ""
        echo -e "${B}${R}ALL DATA on /dev/$SEL_FS, /dev/$SEL_EFI $([ $USE_SWAP -eq 1 ] && echo "and /dev/$SEL_SWAP") WILL BE DESTROYED.${NC}"
        echo ""
        echo -e "${Y}What would you like to do?${NC}"
        v_menu _choice 0 \
            "Let's go! (start install)" \
            "Redo: Partitions (Section 1)" \
            "Redo: Account setup (Section 2)" \
            "Redo: Root account (Section 3)" \
            "Redo: Locale & keyboard (Section 4)" \
            "Redo: QoL & packages (Section 5)"

        case "$_choice" in
            "Let's go!"*) break ;;
            *)
                # Punishment gate
                _pstr="${PUNISHMENT_STRINGS[$RANDOM % ${#PUNISHMENT_STRINGS[@]}]}"
                _section=$(echo "$_choice" | grep -oP 'Section \d+')
                clear
                echo -e "${Y}Oh? You want to redo something? How embarrassing for you.${NC}"
                echo -e "${Y}Before I allow that, you will type the following ${B}exactly${NC}${Y} — case sensitive:${NC}"
                echo ""
                echo -e "  ${B}${C}$_pstr${NC}"
                echo ""
                echo -ne "${Y}Your attempt: ${NC}"; read -r _typed

                if [ "$_typed" = "$_pstr" ]; then
                    echo -e "${Y}...F-fine. I'll allow it. Don't make me regret this. Hmph.${NC}"
                    sleep 1.5
                    case "$_section" in
                        "Section 1") section_1 ;;
                        "Section 2") section_2 ;;
                        "Section 3") section_3 ;;
                        "Section 4") section_4 ;;
                        "Section 5") section_5 ;;
                    esac
                else
                    echo -e "${R}WRONG! That's not what I said, you deaf potato!${NC}"
                    echo -e "${Y}Would you like to try typing it again, or forget it?${NC}"
                    h_menu _punish_result 1 "Try again" "Forget it (back to summary)"
                    if [ "$_punish_result" = "Try again" ]; then
                        echo -ne "${Y}Try again: ${NC}"; read -r _typed
                        if [ "$_typed" = "$_pstr" ]; then
                            echo -e "${Y}...Hmph. Lucky.${NC}"; sleep 1.5
                            case "$_section" in
                                "Section 1") section_1 ;;
                                "Section 2") section_2 ;;
                                "Section 3") section_3 ;;
                                "Section 4") section_4 ;;
                                "Section 5") section_5 ;;
                            esac
                        else
                            echo -e "${R}Unbelievable. Back to the summary with you.${NC}"; sleep 2
                        fi
                    fi
                fi
                ;;
        esac
    done
    log "Section 6 confirmed — proceeding with install"
}

# ════════════════════════════════════════════════════════════════
#  MAIN — Welcome & Section Flow
# ════════════════════════════════════════════════════════════════
clear
echo -e "${B}${Y}"
echo "  ┌──────────────────────────────────────────────────────┐"
echo "  │      Osean's Arch Install Script — Remastered        │"
echo "  └──────────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "${Y}...You're reinstalling AGAIN?! What did you even ${B}do${NC}${Y} to it this time?${NC}"
echo -e "${Y}Fine. FINE. Let's get this over with. At least I'm here to keep you from"
echo -e "completely embarrassing yourself. ...Hmph.${NC}"
echo ""
echo -e "${DIM}Log file: $LOG_FILE${NC}"
echo ""

# Network check
if ! ping -q -c 1 -W 3 archlinux.org &>/dev/null && ! ping -q -c 1 -W 3 8.8.8.8 &>/dev/null; then
    echo -e "${R}No network detected! Connect to the internet first, you absolute walnut.${NC}"
    log_err "Network check failed — aborting"
    exit 1
fi
log_ok "Network connectivity confirmed"

echo -e "${DIM}Press any key to begin...${NC}"
read -rsn1

# ── Run sections ────────────────────────────────────────────────
section_1
section_2
section_3
section_4
section_5
section_6

# ════════════════════════════════════════════════════════════════
#  INSTALLATION
# ════════════════════════════════════════════════════════════════
log_h "INSTALLATION: Formatting"
clear
echo -e "${B}${G}Starting installation. Do NOT touch anything.${NC}\n"
echo -e "${DIM}(For once in your life, just let it happen.)${NC}\n"

echo -e "${Y}Formatting partitions...${NC}"
run mkfs.ext4 -F "/dev/$SEL_FS"
run mkfs.fat -F 32 "/dev/$SEL_EFI"
if [ $USE_SWAP -eq 1 ]; then
    run mkswap "/dev/$SEL_SWAP"
fi

log_h "INSTALLATION: Mounting"
echo -e "${Y}Mounting...${NC}"
run mount "/dev/$SEL_FS" /mnt
mkdir -p /mnt/boot/efi
run mount "/dev/$SEL_EFI" /mnt/boot/efi
if [ $USE_SWAP -eq 1 ]; then
    run swapon "/dev/$SEL_SWAP"
fi

log_h "INSTALLATION: pacstrap"
echo -e "${Y}Running pacstrap (this is the part that actually takes time)...${NC}"
run pacstrap /mnt base linux linux-firmware sof-firmware base-devel git grub efibootmgr nano networkmanager

log_h "INSTALLATION: fstab"
echo -e "${Y}Generating fstab...${NC}"
genfstab -U /mnt > /mnt/etc/fstab
log "fstab written"
cat /mnt/etc/fstab >> "$LOG_FILE"

# ════════════════════════════════════════════════════════════════
#  CREATE SECOND SCRIPT (inside /mnt, runs in chroot)
# ════════════════════════════════════════════════════════════════
log_h "Creating second-stage script"

# Encode passwords to base64 to safely pass them
USER_PASS_B64=$(printf '%s' "$USER_PASS" | base64 -w 0)
ROOT_PASS_B64=$(printf '%s' "$ROOT_PASS" | base64 -w 0)
LOCALES_STR=$(IFS='|'; echo "${LOCALES[*]}")
OPT_PKGS_STR=$(IFS='|'; echo "${OPT_PKGS[*]}")

# Part 1: variable block (expanded now)
cat > /mnt/install_pt2.sh << ENDVARS
#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Arch Install — Stage 2 (chroot)                           ║
# ╚══════════════════════════════════════════════════════════════╝
# Variables passed from stage 1
SEL_DRIVE="$SEL_DRIVE"
SEL_EFI="$SEL_EFI"
SEL_SWAP="$SEL_SWAP"
USE_SWAP=$USE_SWAP
SEL_FS="$SEL_FS"
SYS_NAME="$SYS_NAME"
USERNAME="$USERNAME"
USER_PASS_B64="$USER_PASS_B64"
USE_ROOT=$USE_ROOT
ROOT_PASS_B64="$ROOT_PASS_B64"
LOCALES_STR="$LOCALES_STR"
KEYMAP="$KEYMAP"
INSTALL_YAY=$INSTALL_YAY
INSTALL_SDDM=$INSTALL_SDDM
GPU_TYPE="$GPU_TYPE"
DETECT_OS=$DETECT_OS
AUTOLOGIN=$AUTOLOGIN
OPT_PKGS_STR="$OPT_PKGS_STR"
ENDVARS

# Part 2: script body (single-quoted, no expansion — $ signs are literal)
cat >> /mnt/install_pt2.sh << 'ENDSCRIPT'

# ── Log setup ───────────────────────────────────────────────────
PT2_LOG="/install_pt2.log"
declare -a ISSUES=()

_ts2()    { date '+%H:%M:%S'; }
log2()    { printf '[%s] %s\n'          "$(_ts2)" "$*" >> "$PT2_LOG"; echo -e "  $*"; }
log2_h()  { printf '\n[%s] ════ %s ════\n' "$(_ts2)" "$*" >> "$PT2_LOG"; echo -e "\n\033[1m── $* ──\033[0m"; }
log2_ok() { printf '[%s] ✓ %s\n'        "$(_ts2)" "$*" >> "$PT2_LOG"; echo -e "  \033[0;32m✓ $*\033[0m"; }
log2_err(){ printf '[%s] ✗ ERROR: %s\n' "$(_ts2)" "$*" >> "$PT2_LOG"; echo -e "  \033[0;31m✗ $*\033[0m"; ISSUES+=("$*"); }

run2() {
    log2 "CMD: $*"
    "$@" >> "$PT2_LOG" 2>&1
    local rc=$?
    if [ $rc -ne 0 ]; then log2_err "Failed (rc=$rc): $*"; else log2_ok "Done: $*"; fi
    return $rc
}

printf '╔══════════════════════════════════════════╗\n'         >> "$PT2_LOG"
printf '║  Stage 2 Log — %s  ║\n' "$(date '+%Y-%m-%d %H:%M')" >> "$PT2_LOG"
printf '╚══════════════════════════════════════════╝\n\n'       >> "$PT2_LOG"
log2 "Stage 2 started"

# Decode passwords
USER_PASS=$(printf '%s' "$USER_PASS_B64" | base64 -d)
ROOT_PASS=$(printf '%s' "$ROOT_PASS_B64" | base64 -d)

# Reconstruct arrays
IFS='|' read -ra LOCALES <<< "$LOCALES_STR"
IFS='|' read -ra OPT_PKGS <<< "$OPT_PKGS_STR"

clear
echo -e "\033[1m\033[1;33m"
echo "  Installing Arch Linux — Stage 2"
echo "  'Don't you dare close this terminal. I mean it.'  "
echo -e "\033[0m"
echo "  (Log: $PT2_LOG)"
echo ""

# ── Timezone & clock ────────────────────────────────────────────
log2_h "Timezone & Clock"
run2 ln -sf /usr/share/zoneinfo/America/Lima /etc/localtime
run2 hwclock --systohc

# ── Locales ──────────────────────────────────────────────────────
log2_h "Locales"
for locale in "${LOCALES[@]}"; do
    escaped=$(printf '%s\n' "$locale" | sed 's/[.[\*^$]/\\&/g')
    if grep -q "^#${escaped}$" /etc/locale.gen; then
        run2 sed -i "s|^#${locale}$|${locale}|" /etc/locale.gen
        log2_ok "Enabled locale: $locale"
    else
        log2_err "Could not find locale to uncomment: $locale"
    fi
done
run2 locale-gen

# Set LANG to first locale
FIRST_LOCALE="${LOCALES[0]}"
LANG_SETTING=$(echo "$FIRST_LOCALE" | awk '{print $1}')
echo "LANG=$LANG_SETTING" > /etc/locale.conf
log2_ok "Set LANG=$LANG_SETTING"

# ── Keymap ───────────────────────────────────────────────────────
log2_h "Keymap"
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
log2_ok "Keymap set to: $KEYMAP"

# ── Hostname ─────────────────────────────────────────────────────
log2_h "Hostname"
echo "$SYS_NAME" > /etc/hostname
log2_ok "Hostname: $SYS_NAME"

# ── Root account ──────────────────────────────────────────────────
log2_h "Root Account"
if [ "$USE_ROOT" -eq 1 ]; then
    echo "root:${ROOT_PASS}" | chpasswd
    log2_ok "Root account password set"
else
    run2 passwd -l root
    log2_ok "Root account locked"
fi

# ── User creation ────────────────────────────────────────────────
log2_h "User Creation"
run2 useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "${USERNAME}:${USER_PASS}" | chpasswd
log2_ok "User '$USERNAME' created"

# ── Visudo — enable wheel group ──────────────────────────────────
log2_h "Sudo Configuration"
if grep -q '^# %wheel ALL=(ALL:ALL) ALL' /etc/sudoers; then
    run2 sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    log2_ok "Wheel group sudo access enabled"
else
    log2_err "Could not uncomment wheel in /etc/sudoers — check it manually"
fi

# ── Multilib ─────────────────────────────────────────────────────
log2_h "Multilib"
if grep -q '^\[multilib\]' /etc/pacman.conf; then
    log2_ok "Multilib already enabled"
else
    run2 sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    log2_ok "Multilib enabled in pacman.conf"
fi

# ── NetworkManager ───────────────────────────────────────────────
log2_h "NetworkManager"
run2 systemctl enable NetworkManager

# ── System update ────────────────────────────────────────────────
log2_h "System Update (pacman -Syu)"
run2 pacman -Syu --noconfirm

# ── GRUB ─────────────────────────────────────────────────────────
log2_h "GRUB"
run2 grub-install "/dev/$SEL_DRIVE"
run2 grub-mkconfig -o /boot/grub/grub.cfg

# ── yay ──────────────────────────────────────────────────────────
if [ "$INSTALL_YAY" -eq 1 ]; then
    log2_h "Installing yay (AUR helper)"
    (
        cd /tmp
        sudo -u "$USERNAME" git clone https://aur.archlinux.org/yay-bin.git yay-bin-aur
        cd yay-bin-aur
        sudo -u "$USERNAME" makepkg -si --noconfirm
        cd /
        rm -rf /tmp/yay-bin-aur
    ) >> "$PT2_LOG" 2>&1 && log2_ok "yay installed" || log2_err "yay installation failed — check $PT2_LOG"
fi

# ── SDDM ─────────────────────────────────────────────────────────
if [ "$INSTALL_SDDM" -eq 1 ]; then
    log2_h "SDDM"
    run2 pacman -S --needed --noconfirm sddm
    run2 systemctl enable sddm
fi

# ── OS Prober ────────────────────────────────────────────────────
if [ "$DETECT_OS" -eq 1 ]; then
    log2_h "OS Prober (multi-boot detection)"
    run2 pacman -S --needed --noconfirm os-prober
    if grep -q '^#GRUB_DISABLE_OS_PROBER=false' /etc/default/grub; then
        run2 sed -i 's/^#GRUB_DISABLE_OS_PROBER=false$/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
        log2_ok "OS prober enabled in GRUB config"
    else
        log2_err "Could not find GRUB_DISABLE_OS_PROBER in /etc/default/grub — add it manually"
    fi
    # Mount sibling partitions so os-prober can find them
    for p in /dev/${SEL_DRIVE}?*; do
        [ "$p" = "/dev/$SEL_DRIVE" ] && continue
        mnt_point="/mnt/$(basename "$p")"
        mkdir -p "$mnt_point"
        mount "$p" "$mnt_point" 2>/dev/null && log2 "Mounted $p at $mnt_point for os-prober" || true
    done
    run2 grub-mkconfig -o /boot/grub/grub.cfg
fi

# ── Autologin ────────────────────────────────────────────────────
if [ "$AUTOLOGIN" -eq 1 ]; then
    log2_h "Autologin (TTY1)"
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat > /etc/systemd/system/getty@tty1.service.d/override.conf << AUTOLOGIN_EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${USERNAME} --noclear %I \$TERM
AUTOLOGIN_EOF
    log2_ok "Autologin configured for $USERNAME on TTY1"
fi

# ── GPU Drivers ──────────────────────────────────────────────────
log2_h "GPU Drivers"
case "$GPU_TYPE" in
    intel)
        run2 pacman -S --needed --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel
        ;;
    RTX|GTX|Athlon)
        log2_err "GPU type '$GPU_TYPE' driver installation not yet implemented — skipped"
        ;;
    broke|*)
        log2 "No GPU drivers to install (broke boi mode or unrecognized: $GPU_TYPE)"
        ;;
esac

# ── Optional Packages ────────────────────────────────────────────
if [ ${#OPT_PKGS[@]} -gt 0 ]; then
    log2_h "Optional Packages"
    PKGS_TO_INSTALL=""
    for pkg_name in "${OPT_PKGS[@]}"; do
        case "$pkg_name" in
            "Firefox")                        PKGS_TO_INSTALL="$PKGS_TO_INSTALL firefox" ;;
            "Code (VS Code)")                 PKGS_TO_INSTALL="$PKGS_TO_INSTALL code" ;;
            "Dolphin (file manager)")         PKGS_TO_INSTALL="$PKGS_TO_INSTALL dolphin" ;;
            "Kitty (terminal)")               PKGS_TO_INSTALL="$PKGS_TO_INSTALL kitty" ;;
            "Basic Fonts"*)                   PKGS_TO_INSTALL="$PKGS_TO_INSTALL ttf-hack ttf-dejavu ttf-jetbrains-mono ttf-nerd-fonts-symbols" ;;
        esac
    done
    if [ -n "$PKGS_TO_INSTALL" ]; then
        # shellcheck disable=SC2086
        run2 pacman -S --needed --noconfirm $PKGS_TO_INSTALL
    fi
fi

# ── Final Report ─────────────────────────────────────────────────
clear
echo ""
echo -e "\033[1m╔═══════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1m║          POST-INSTALLATION REPORT                 ║\033[0m"
echo -e "\033[1m╚═══════════════════════════════════════════════════╝\033[0m"
echo ""

if [ ${#ISSUES[@]} -eq 0 ]; then
    echo -e "  \033[0;32m✓ No issues encountered! Everything went smoothly.\033[0m"
    echo -e "  \033[2m...Not that I'm impressed or anything. Hmph.\033[0m"
else
    echo -e "  \033[0;31mThe following issues occurred (check $PT2_LOG for details):\033[0m"
    echo ""
    for issue in "${ISSUES[@]}"; do
        echo -e "  \033[0;31m[!]\033[0m $issue"
    done
    echo ""
    echo -e "  \033[1;33mReview $PT2_LOG before rebooting!\033[0m"
fi

echo ""
echo -e "  Log saved at: \033[0;36m$PT2_LOG\033[0m"
echo -e "  \033[2mDelete it yourself when you're sure everything's working.\033[0m"
echo ""
echo -e "  \033[1;33mType 'exit' then 'umount -R /mnt' then 'reboot'.\033[0m"
echo -e "  \033[2m...Try not to break it again within the first 5 minutes. Please.\033[0m"
echo ""

# Self-destruct
sudo rm -f /install_pt2.sh
ENDSCRIPT

chmod +x /mnt/install_pt2.sh
log_ok "Second script written to /mnt/install_pt2.sh"

# ── Enter chroot and run stage 2 ────────────────────────────────
log_h "Entering chroot — running stage 2"
echo -e "\n${Y}Entering system environment for final configuration...${NC}\n"
arch-chroot /mnt /bin/bash /install_pt2.sh

log_h "arch-chroot completed"
log_ok "Installation finished"
echo ""
echo -e "${Y}Stage 2 complete! If everything looks good above, you can now:${NC}"
echo -e "  ${B}umount -R /mnt${NC}  then  ${B}reboot${NC}"
echo ""
echo -e "${DIM}Log from this first stage: $LOG_FILE${NC}"
echo -e "${DIM}(It'll be gone once you reboot from the live ISO, so check it now if needed.)${NC}"
echo ""