#!/bin/bash
# =============================================================================
#  Osean's Arch Install Script — Enhanced Tsundere Edition
#  w-What?! AGAIN?! What did you DO to the last one?! BAKAA!
# =============================================================================

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; PINK='\033[1;35m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/arch_install.log"

_log() { printf '[%s] [%-5s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >> "$LOG_FILE"; }
log_info()  { _log "INFO"  "$*"; }
log_warn()  { _log "WARN"  "$*"; }
log_error() { _log "ERROR" "$*"; }
log_sep()   { printf '%.0s─' {1..60} >> "$LOG_FILE"; printf '\n' >> "$LOG_FILE"; }

run_logged() {
    log_info "CMD: $*"
    local out; out=$("$@" 2>&1); local ret=$?
    printf '%s\n' "$out" >> "$LOG_FILE"
    [[ $ret -ne 0 ]] && log_error "FAILED (exit $ret): $*"
    return $ret
}
run_tee() {
    log_info "CMD: $*"
    "$@" 2>&1 | tee -a "$LOG_FILE"
    return "${PIPESTATUS[0]}"
}

{ printf '%.0s═' {1..60}; printf '\n Arch Install Log — %s\n Script: %s\n' "$(date)" "$SCRIPT_DIR"
  printf '%.0s═' {1..60}; printf '\n\n'; } > "$LOG_FILE"

trap 'tput cnorm 2>/dev/null' EXIT

# ── Key reader ────────────────────────────────────────────────────────────────
_read_key() {
    local k seq
    IFS= read -r -s -n1 k
    if [[ "$k" == $'\x1b' ]]; then
        IFS= read -r -s -n2 -t 0.1 seq
        case "$seq" in
            '[A') printf 'UP';;    '[B') printf 'DOWN';;
            '[C') printf 'RIGHT';; '[D') printf 'LEFT';; *) printf 'ESC';;
        esac
    elif [[ -z "$k" ]]; then printf 'ENTER'
    elif [[ "$k" == ' ' ]]; then printf 'SPACE'
    else printf 'CHAR:%s' "$k"; fi
}

# ── Horizontal single-select: result=$(hmenu opt1 opt2 ...) ──────────────────
hmenu() {
    local opts=("$@") sel=0 n=$# k
    tput civis 2>/dev/null
    while true; do
        printf '\r\033[K  '
        for i in "${!opts[@]}"; do
            [[ $i -eq $sel ]] \
                && printf "${BOLD}${GREEN}[%s]${NC}" "${opts[$i]}" \
                || printf "${DIM} %s ${NC}" "${opts[$i]}"
            [[ $i -lt $((n-1)) ]] && printf '  '
        done
        k=$(_read_key)
        case "$k" in
            RIGHT|DOWN) ((sel < n-1)) && ((sel++));;
            LEFT|UP)    ((sel > 0))   && ((sel--));;
            ENTER) break;;
        esac
    done
    printf '\n'; tput cnorm 2>/dev/null; printf '%s' "${opts[$sel]}"
}

# ── Vertical single-select: result=$(vmenu opt1 opt2 ...) ────────────────────
vmenu() {
    local opts=("$@") sel=0 n=$# k
    tput civis 2>/dev/null
    for _ in "${opts[@]}"; do printf '\n'; done
    while true; do
        tput cuu "$n" 2>/dev/null
        for i in "${!opts[@]}"; do
            printf '\r\033[K'
            [[ $i -eq $sel ]] \
                && printf "  ${BOLD}${GREEN}> %s${NC}\n" "${opts[$i]}" \
                || printf "    %s\n" "${opts[$i]}"
        done
        k=$(_read_key)
        case "$k" in
            UP)    ((sel > 0))   && ((sel--));;
            DOWN)  ((sel < n-1)) && ((sel++));;
            ENTER) break;;
        esac
    done
    tput cnorm 2>/dev/null; printf '%s' "${opts[$sel]}"
}

# ── Checkbox menu: cbmenu ARRAY_VAR opt1 opt2 ... (modifies array in-place) ──
cbmenu() {
    local -n _cb="$1"; shift
    local opts=("$@") n=$# total=$(($#+1)) sel=0 k
    printf "${DIM}  [Space/Enter] toggle  [Up/Down] move  [Enter on Continue] done${NC}\n"
    tput civis 2>/dev/null
    for _ in $(seq 1 $total); do printf '\n'; done
    while true; do
        tput cuu "$total" 2>/dev/null
        for i in "${!opts[@]}"; do
            printf '\r\033[K'
            local box; [[ "${_cb[$i]:-0}" == '1' ]] && box="${GREEN}x${NC}" || box=' '
            [[ $i -eq $sel ]] \
                && printf "  ${BOLD}${GREEN}> [${NC}${box}${BOLD}${GREEN}] %s${NC}\n" "${opts[$i]}" \
                || printf "    [${box}] %s\n" "${opts[$i]}"
        done
        printf '\r\033[K'
        [[ $sel -eq $n ]] \
            && printf "  ${BOLD}${CYAN}> [ Continue ]${NC}\n" \
            || printf "    [ Continue ]\n"
        k=$(_read_key)
        case "$k" in
            UP)    ((sel > 0))       && ((sel--));;
            DOWN)  ((sel < total-1)) && ((sel++));;
            SPACE|ENTER)
                if [[ $sel -eq $n ]]; then [[ "$k" == 'ENTER' ]] && break
                else [[ "${_cb[$sel]:-0}" == '1' ]] && _cb[$sel]='0' || _cb[$sel]='1'; fi;;
        esac
    done
    tput cnorm 2>/dev/null
}

# ── Yes/No: result=$(ynmenu [yes|no]) ─────────────────────────────────────────
ynmenu() {
    local sel=0 k; [[ "${1:-yes}" == 'no' ]] && sel=1
    tput civis 2>/dev/null; printf '\n'
    while true; do
        tput cuu 1 2>/dev/null; printf '\r\033[K  '
        [[ $sel -eq 0 ]] \
            && printf "${BOLD}${GREEN}[ Yes ]${NC}    ${DIM}No${NC}\n" \
            || printf "${DIM}Yes${NC}    ${BOLD}${RED}[ No ]${NC}\n"
        k=$(_read_key)
        case "$k" in RIGHT|DOWN) sel=1;; LEFT|UP) sel=0;; ENTER) break;; esac
    done
    tput cnorm 2>/dev/null
    [[ $sel -eq 0 ]] && printf 'yes' || printf 'no'
}

pause() { printf '\n  %s' "${1:-Press any key to continue...}"; IFS= read -r -s -n1; printf '\n'; }

# ── Tsundere ──────────────────────────────────────────────────────────────────
PUNISHMENTS=(
    "I'm sorry boss, please allow me to retry."
    "Forgive my incompetence, I shall do better."
    "Yes yes, my fault, let me fix this at once."
    "I deeply apologize for my careless mistake."
    "Please grant me one more chance to get this right."
    "I humbly request permission to redo this section."
    "My sincerest apologies, I will not fail again."
    "You are right as always, please let me retry."
    "I acknowledge my error and beg for another attempt."
    "Allow me to correct my foolish mistake, please."
)

punishment_prompt() {
    local str="${PUNISHMENTS[$((RANDOM % ${#PUNISHMENTS[@]}))]}"
    printf '\n'
    printf "${PINK}${BOLD}  ...Fine, I'll let you redo it. IF you can type this exactly:\n${NC}"
    printf '\n  '
    printf "${YELLOW}${BOLD}\"%s\"${NC}\n\n" "$str"
    while true; do
        printf '  > '; local attempt; IFS= read -r attempt
        if [[ "$attempt" == "$str" ]]; then
            printf "${PINK}  ...You actually got it right. Don't push your luck.${NC}\n\n"
            return 0
        else
            printf "${RED}${BOLD}  WRONG! You can't even copy text?!${NC}\n\n"
            local c; c=$(vmenu "Try again" "Forget it, go back to summary")
            [[ "$c" == "Forget it, go back to summary" ]] && {
                printf "${PINK}  Thought so. Back you go.${NC}\n\n"; return 1; }
            printf '\n'
        fi
    done
}

# =============================================================================
# SECTION 1 — Drive & Partition Selection
# =============================================================================
# Sets: input_parent, input_efi, input_swap, use_swap, input_filesystem

section1() {
    local restart=true
    while $restart; do
        restart=false

        # ── Drive selection ───────────────────────────────────────────────────
        while true; do
            clear
            printf "${BOLD}${CYAN}╔════════════════════════════════════════╗${NC}\n"
            printf "${BOLD}${CYAN}║  Section 1 — Drive & Partition Setup   ║${NC}\n"
            printf "${BOLD}${CYAN}╚════════════════════════════════════════╝${NC}\n\n"
            lsblk; printf '\n'
            log_info "lsblk displayed to user"

            mapfile -t _DRIVES < <(lsblk -dpno NAME | grep -Ev 'loop|sr[0-9]' | sed 's|/dev/||')
            [[ ${#_DRIVES[@]} -eq 0 ]] && { printf "${RED}No drives found. Huh.${NC}\n"; log_error "No drives found"; exit 1; }

            printf "${BOLD}  Select target drive:${NC}\n"
            printf "${DIM}  [left/right] navigate  [Enter] select${NC}\n\n"
            input_parent=$(hmenu "${_DRIVES[@]}")
            printf '\n'; log_info "Drive selected: /dev/$input_parent"

            # ── Drive action loop ─────────────────────────────────────────────
            while true; do
                clear
                printf "${BOLD}${CYAN}  Drive: /dev/$input_parent${NC}\n\n"
                lsblk "/dev/$input_parent"; printf '\n'
                local _act
                _act=$(vmenu \
                    "Continue with this drive" \
                    "Manage partitions (cfdisk)" \
                    "Pick a different drive")
                printf '\n'
                case "$_act" in
                    "Continue with this drive")
                        log_info "Drive confirmed: /dev/$input_parent"; break 2;;
                    "Manage partitions (cfdisk)")
                        log_info "Launching cfdisk on /dev/$input_parent"
                        cfdisk "/dev/$input_parent"; clear
                        log_info "cfdisk exited";;
                    "Pick a different drive")
                        log_info "User picking different drive"; break;;
                esac
            done
        done

        # ── Partition selection ───────────────────────────────────────────────
        clear
        printf "${BOLD}${CYAN}  Partition Selection — /dev/$input_parent${NC}\n\n"
        lsblk "/dev/$input_parent"; printf '\n'

        mapfile -t _PARTS < <(lsblk -lno NAME "/dev/$input_parent" | grep -v "^${input_parent}$")
        if [[ ${#_PARTS[@]} -eq 0 ]]; then
            printf "${RED}  No partitions found. Create them first.${NC}\n"
            log_error "No partitions on /dev/$input_parent"; pause
            restart=true; continue
        fi

        printf "${BOLD}  EFI System Partition:${NC}\n"
        printf "${DIM}  Recommended: 100MB–300MB, type EFI System${NC}\n\n"
        input_efi=$(vmenu "${_PARTS[@]}")
        log_info "EFI: /dev/$input_efi"

        printf '\n'
        printf "${BOLD}  Use a SWAP partition?${NC}\n"
        printf "${DIM}  (Modern systems with 16GB+ RAM often skip this)${NC}\n"
        use_swap=$(ynmenu "no")
        log_info "use_swap=$use_swap"

        input_swap=""
        if [[ "$use_swap" == "yes" ]]; then
            printf '\n'
            printf "${BOLD}  SWAP Partition:${NC}\n"
            printf "${DIM}  Recommended: 4GB–8GB${NC}\n\n"
            input_swap=$(vmenu "${_PARTS[@]}")
            log_info "SWAP: /dev/$input_swap"
        fi

        printf '\n'
        printf "${BOLD}  Root Filesystem Partition:${NC}\n"
        printf "${DIM}  30GB bare  |  50GB standard  |  80GB recommended  |  150GB+ heavy${NC}\n\n"
        input_filesystem=$(vmenu "${_PARTS[@]}")
        log_info "Filesystem: /dev/$input_filesystem"

        # ── Summary + confirm ─────────────────────────────────────────────────
        clear
        printf "${BOLD}${CYAN}  Partition Layout${NC}\n\n"
        lsblk; printf '\n'
        printf "  Parent drive : ${BOLD}/dev/$input_parent${NC}\n"
        printf "  EFI          : ${BOLD}/dev/$input_efi${NC}\n"
        [[ "$use_swap" == "yes" ]] \
            && printf "  SWAP         : ${BOLD}/dev/$input_swap${NC}\n" \
            || printf "  SWAP         : ${DIM}(none)${NC}\n"
        printf "  Root FS      : ${BOLD}/dev/$input_filesystem${NC}\n\n"

        local _confirm
        _confirm=$(vmenu "Looks good, continue" "Start section over")
        if [[ "$_confirm" == "Start section over" ]]; then
            log_info "User restarting section 1"; restart=true
        else
            log_info "Section 1 confirmed"
            log_sep
            log_info "Drive: /dev/$input_parent  EFI: /dev/$input_efi  SWAP: ${input_swap:-(none)}  FS: /dev/$input_filesystem"
        fi
    done
}

# =============================================================================
# SECTION 2 — System Details
# =============================================================================
# Sets: input_systemname, input_username, input_password

section2() {
    local _restart=true
    while $_restart; do
        _restart=false
        clear
        printf "${BOLD}${CYAN}╔══════════════════════════════════╗${NC}\n"
        printf "${BOLD}${CYAN}║  Section 2 — System Details      ║${NC}\n"
        printf "${BOLD}${CYAN}╚══════════════════════════════════╝${NC}\n"
        printf "${PINK}  ...I hope you can at least spell your own username.${NC}\n\n"

        while true; do
            printf "  Hostname: "; IFS= read -r input_systemname
            [[ "$input_systemname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]] && break
            printf "${RED}  Invalid. Letters, numbers, hyphens only (no leading/trailing hyphen).${NC}\n"
        done

        while true; do
            printf "  Username: "; IFS= read -r input_username
            [[ "$input_username" =~ ^[a-z][a-z0-9_-]*$ ]] && break
            printf "${RED}  Lowercase only, must start with a letter.${NC}\n"
        done

        while true; do
            printf "  Password: "; IFS= read -rs input_password; printf '\n'
            printf "  Confirm : "; IFS= read -rs _pw2; printf '\n'
            [[ -z "$input_password" ]] && { printf "${RED}  Empty password? Seriously?${NC}\n"; continue; }
            [[ "$input_password" == "$_pw2" ]] && break
            printf "${RED}  Passwords don't match. Try again.${NC}\n"
        done

        # Summary loop
        while true; do
            clear
            printf "${BOLD}${CYAN}  System Details${NC}\n\n"
            printf "  Hostname : ${BOLD}%s${NC}\n" "$input_systemname"
            printf "  Username : ${BOLD}%s${NC}\n" "$input_username"
            printf "  Password : ${BOLD}%s${NC}\n\n" "$(printf '*%.0s' $(seq 1 ${#input_password}))"
            local _c; _c=$(vmenu "Looks right, continue" "Redo this section" "Test my password")
            case "$_c" in
                "Looks right, continue")
                    log_info "Section 2 confirmed: host=$input_systemname user=$input_username"; break 2;;
                "Redo this section")
                    log_info "User redoing section 2"; _restart=true; break;;
                "Test my password")
                    printf '\n  Enter password to test: '; IFS= read -rs _tp; printf '\n'
                    [[ "$_tp" == "$input_password" ]] \
                        && printf "${GREEN}  Correct! Nice.${NC}\n" \
                        || printf "${RED}  Nope. Yikes.${NC}\n"
                    pause;;
            esac
        done
    done
}

# =============================================================================
# SECTION 3 — Root Account
# =============================================================================
# Sets: enable_root, root_password

section3() {
    clear
    printf "${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}\n"
    printf "${BOLD}${CYAN}║  Section 3 — Root Account            ║${NC}\n"
    printf "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}\n"
    printf "${DIM}  Root is the system admin. Login name is always 'root'.${NC}\n"
    printf "${DIM}  Most modern setups don't need it enabled. I personally never have.${NC}\n\n"

    enable_root='no'; root_password=''
    printf "${BOLD}  Enable root account?${NC}\n"
    enable_root=$(ynmenu "no")

    if [[ "$enable_root" == "yes" ]]; then
        printf '\n'
        printf "${DIM}  (Username is 'root'. Not configurable here.)${NC}\n\n"
        while true; do
            printf "  Root password : "; IFS= read -rs root_password; printf '\n'
            printf "  Confirm       : "; IFS= read -rs _rp2; printf '\n'
            if [[ "$root_password" != "$_rp2" ]]; then
                printf "${RED}  Passwords don't match.${NC}\n"
                local _m; _m=$(vmenu "Try again" "Forget it (disable root)")
                [[ "$_m" == "Forget it (disable root)" ]] && { enable_root='no'; root_password=''; break; }
                continue
            fi
            if [[ "$root_password" == "$input_password" ]]; then
                printf '\n'
                printf "${YELLOW}  That's the same password as your user account.${NC}\n"
                printf "${YELLOW}  Linux forum people would riot. But I'm not your mom.${NC}\n\n"
                local _s; _s=$(vmenu "Keep it (I do what I want)" "Use a different password" "Forget it (disable root)")
                case "$_s" in
                    "Keep it (I do what I want)") break;;
                    "Use a different password") continue;;
                    "Forget it (disable root)") enable_root='no'; root_password=''; break;;
                esac
            else
                break
            fi
        done
    fi
    log_info "Root account: $enable_root"
}

# =============================================================================
# SECTION 4 — Locales & Keyboard
# =============================================================================
# Sets: selected_locales (array), keymap

section4() {
    local _restart=true
    while $_restart; do
        _restart=false
        clear
        printf "${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}\n"
        printf "${BOLD}${CYAN}║  Section 4 — Locale & Keyboard       ║${NC}\n"
        printf "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}\n\n"

        local LOCALE_OPTS=("en_US.UTF-8 UTF-8" "ja_JP.UTF-8 UTF-8" "es_PE.UTF-8 UTF-8")
        locale_checked=(1 0 0)

        printf "${BOLD}  Select locale(s):${NC}\n"
        while true; do
            cbmenu "locale_checked" "${LOCALE_OPTS[@]}"
            local _any=0
            for _v in "${locale_checked[@]}"; do [[ "$_v" == "1" ]] && { _any=1; break; }; done
            [[ $_any -eq 1 ]] && break
            printf "${RED}${BOLD}  Pick at LEAST one locale. Don't test me.${NC}\n"; sleep 1
        done

        selected_locales=()
        for i in "${!LOCALE_OPTS[@]}"; do
            [[ "${locale_checked[$i]}" == "1" ]] && selected_locales+=("${LOCALE_OPTS[$i]}")
        done
        log_info "Locales: ${selected_locales[*]}"

        printf '\n'
        printf "${BOLD}  Keyboard layout:${NC}\n"
        printf "${DIM}  Only one can be active at a time.${NC}\n\n"
        local _km; _km=$(vmenu "us  (US QWERTY)" "es  (Spanish)" "jp106  (Japanese 106-key)")
        keymap="${_km%% *}"
        log_info "Keymap: $keymap"

        clear
        printf "${BOLD}${CYAN}  Locale Summary${NC}\n\n"
        printf "  Timezone : ${BOLD}America/Lima${NC} ${DIM}(hardcoded, yes)${NC}\n"
        printf "  Locales  : ${BOLD}%s${NC}\n" "${selected_locales[*]}"
        printf "  Keymap   : ${BOLD}%s${NC}\n" "$keymap"
        printf "  Multilib : ${BOLD}enabled automatically${NC}\n\n"

        local _ok; _ok=$(vmenu "Looks good, continue" "Redo this section")
        [[ "$_ok" == "Redo this section" ]] && { log_info "Retrying section 4"; _restart=true; }
    done
    log_info "Section 4 confirmed"
}

# =============================================================================
# SECTION 5 — Optional Software & Settings
# =============================================================================
# Sets: install_yay, install_sddm, gpu_type, detect_os, autologin
#       optional_packages (array)

section5() {
    local _restart=true
    while $_restart; do
        _restart=false
        clear
        printf "${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}\n"
        printf "${BOLD}${CYAN}║  Section 5 — Optional Stuff          ║${NC}\n"
        printf "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}\n\n"

        printf "${BOLD}  Install yay? ${DIM}(AUR helper — yay-bin)${NC}\n"
        install_yay=$(ynmenu "yes")
        [[ "$install_yay" == "no" ]] && printf "${PINK}  ...okay, beta.${NC}\n"
        printf '\n'

        printf "${BOLD}  Install and enable SDDM?${NC}\n"
        install_sddm=$(ynmenu "yes")
        [[ "$install_sddm" == "no" ]] && printf "${PINK}  soy boy.${NC}\n"
        printf '\n'

        printf "${BOLD}  GPU type:${NC}\n"
        printf "${DIM}  RTX/GTX/Athlon: noted for the future, not wired up yet${NC}\n\n"
        local _gpu; _gpu=$(vmenu \
            "Intel iGPU" \
            "RTX  (driver not implemented, skips)" \
            "GTX  (driver not implemented, skips)" \
            "Athlon/AMD  (driver not implemented, skips)" \
            "None / broke boi")
        case "$_gpu" in
            "Intel iGPU") gpu_type="intel";;
            "RTX"*)        gpu_type="rtx";;
            "GTX"*)        gpu_type="gtx";;
            "Athlon"*)     gpu_type="athlon";;
            *)             gpu_type="none";;
        esac
        log_info "GPU: $gpu_type"; printf '\n'

        printf "${BOLD}  Detect other OSes via GRUB? ${DIM}(for dual-boot)${NC}\n"
        detect_os=$(ynmenu "no")
        [[ "$detect_os" == "no" ]] && printf "${PINK}  baka.${NC}\n"
        printf '\n'

        printf "${BOLD}  Enable autologin?${NC}\n"
        autologin=$(ynmenu "no")
        printf '\n'

        printf "${BOLD}  Optional packages:${NC}\n"
        printf "${DIM}  None required. Pick whatever you want.${NC}\n\n"
        local PKG_OPTS=(
            "firefox"
            "code  (VS Code)"
            "dolphin  (file manager)"
            "kitty  (terminal)"
            "basic fonts  (ttf-hack ttf-dejavu ttf-jetbrains-mono ttf-nerd-fonts-symbols)"
        )
        pkg_checked=(0 0 0 0 0)
        cbmenu "pkg_checked" "${PKG_OPTS[@]}"

        optional_packages=()
        [[ "${pkg_checked[0]}" == "1" ]] && optional_packages+=("firefox")
        [[ "${pkg_checked[1]}" == "1" ]] && optional_packages+=("code")
        [[ "${pkg_checked[2]}" == "1" ]] && optional_packages+=("dolphin")
        [[ "${pkg_checked[3]}" == "1" ]] && optional_packages+=("kitty")
        [[ "${pkg_checked[4]}" == "1" ]] && optional_packages+=("ttf-hack" "ttf-dejavu" "ttf-jetbrains-mono" "ttf-nerd-fonts-symbols")

        [[ ${#optional_packages[@]} -eq 0 ]] && \
            printf '\n'"${PINK}  k, that was the last time I do anything nice for you. Hmph.${NC}\n"
        log_info "Optional packages: ${optional_packages[*]:-none}"

        clear
        printf "${BOLD}${CYAN}  Section 5 Summary${NC}\n\n"
        printf "  yay       : ${BOLD}%s${NC}\n" "$install_yay"
        printf "  SDDM      : ${BOLD}%s${NC}\n" "$install_sddm"
        printf "  GPU       : ${BOLD}%s${NC}\n" "$gpu_type"
        printf "  OS detect : ${BOLD}%s${NC}\n" "$detect_os"
        printf "  Autologin : ${BOLD}%s${NC}\n" "$autologin"
        printf "  Packages  : ${BOLD}%s${NC}\n\n" "${optional_packages[*]:-none}"

        local _s5; _s5=$(vmenu "All good, continue" "Redo this section")
        [[ "$_s5" == "Redo this section" ]] && { log_info "Retrying section 5"; _restart=true; }
    done
    log_info "Section 5 confirmed"
}

# =============================================================================
# SECTION 6 — Final Rundown & Retry
# =============================================================================

show_summary() {
    clear
    printf "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}\n"
    printf "${BOLD}${CYAN}║            FINAL RUNDOWN — Section 6             ║${NC}\n"
    printf "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}\n\n"

    printf "${YELLOW}${BOLD}[ Drive & Partitions ]${NC}\n"
    printf "  Parent drive : /dev/%s\n" "$input_parent"
    printf "  EFI          : /dev/%s\n" "$input_efi"
    [[ "$use_swap" == "yes" ]] \
        && printf "  SWAP         : /dev/%s\n" "$input_swap" \
        || printf "  SWAP         : (none)\n"
    printf "  Root FS      : /dev/%s\n\n" "$input_filesystem"

    printf "${YELLOW}${BOLD}[ System Details ]${NC}\n"
    printf "  Hostname  : %s\n" "$input_systemname"
    printf "  Username  : %s\n" "$input_username"
    printf "  Password  : %s\n\n" "$(printf '*%.0s' $(seq 1 ${#input_password}))"

    printf "${YELLOW}${BOLD}[ Root Account ]${NC}\n"
    if [[ "$enable_root" == "yes" ]]; then
        printf "  Status    : ENABLED\n"
        printf "  Password  : %s\n\n" "$(printf '*%.0s' $(seq 1 ${#root_password}))"
    else
        printf "  Status    : disabled (locked)\n\n"
    fi

    printf "${YELLOW}${BOLD}[ Locale & Keyboard ]${NC}\n"
    printf "  Timezone  : America/Lima\n"
    printf "  Locales   : %s\n" "${selected_locales[*]}"
    printf "  Keymap    : %s\n" "$keymap"
    printf "  Multilib  : enabled\n\n"

    printf "${YELLOW}${BOLD}[ Optional Software ]${NC}\n"
    printf "  yay       : %s\n" "$install_yay"
    printf "  SDDM      : %s\n" "$install_sddm"
    printf "  GPU       : %s\n" "$gpu_type"
    printf "  OS detect : %s\n" "$detect_os"
    printf "  Autologin : %s\n" "$autologin"
    printf "  Packages  : %s\n\n" "${optional_packages[*]:-none}"
}

section6() {
    while true; do
        show_summary
        local _s6; _s6=$(vmenu \
            "==> INSTALL (no going back)" \
            "Retry: Section 2 (System Details)" \
            "Retry: Section 3 (Root Account)" \
            "Retry: Section 4 (Locale & Keyboard)" \
            "Retry: Section 5 (Optional Software)")
        case "$_s6" in
            "==> INSTALL (no going back)")
                log_info "User confirmed installation — proceeding"; log_sep; break;;
            "Retry: Section 2 (System Details)")
                punishment_prompt && section2;;
            "Retry: Section 3 (Root Account)")
                punishment_prompt && section3;;
            "Retry: Section 4 (Locale & Keyboard)")
                punishment_prompt && section4;;
            "Retry: Section 5 (Optional Software)")
                punishment_prompt && section5;;
        esac
    done
}

# =============================================================================
# MAIN FLOW
# =============================================================================

if ! ping -q -c 1 -W 3 archlinux.org &>/dev/null; then
    printf "${RED}${BOLD}No network. Fix that and try again.${NC}\n"
    log_error "No network"; exit 1
fi
log_info "Network OK"

clear
printf '\n'
printf "${BOLD}${CYAN}  ╔═══════════════════════════════════════════╗${NC}\n"
printf "${BOLD}${CYAN}  ║       Osean's Arch Installer              ║${NC}\n"
printf "${BOLD}${CYAN}  ╚═══════════════════════════════════════════╝${NC}\n\n"
printf "${PINK}${BOLD}  W-What?! You're reinstalling Arch AGAIN?!${NC}\n"
printf "${PINK}  What did you even DO to the last one?! BAKAA!${NC}\n"
printf "${PINK}  ...Fine. Don't make me regret this.${NC}\n\n"
log_info "Script started"
pause "Press any key to begin the setup..."

section1
section2
section3
section4
section5
section6

# =============================================================================
# INSTALLATION
# =============================================================================

log_sep; log_info "=== INSTALLATION PHASE ==="; log_sep

clear
printf "${BOLD}${CYAN}╔════════════════════════════════════════╗${NC}\n"
printf "${BOLD}${CYAN}║     Installation in progress...        ║${NC}\n"
printf "${BOLD}${CYAN}╚════════════════════════════════════════╝${NC}\n\n"
printf "${PINK}  FINE. I'll do it. You owe me.${NC}\n\n"

# ── Format ────────────────────────────────────────────────────────────────────
printf "${BOLD}  Formatting partitions...${NC}\n"
log_info "Formatting /dev/$input_filesystem as ext4"
if ! run_logged mkfs.ext4 -F "/dev/$input_filesystem"; then
    printf "${RED}  ERROR: mkfs.ext4 failed on /dev/$input_filesystem${NC}\n"; exit 1; fi

log_info "Formatting /dev/$input_efi as FAT32"
if ! run_logged mkfs.fat -F 32 "/dev/$input_efi"; then
    printf "${RED}  ERROR: mkfs.fat failed on /dev/$input_efi${NC}\n"; exit 1; fi

if [[ "$use_swap" == "yes" ]]; then
    log_info "Setting up swap on /dev/$input_swap"
    run_logged mkswap "/dev/$input_swap" || log_warn "mkswap had issues (non-fatal)"
fi
printf "${GREEN}  Partitions formatted.${NC}\n\n"

# ── Mount ─────────────────────────────────────────────────────────────────────
printf "${BOLD}  Mounting filesystems...${NC}\n"
if ! run_logged mount "/dev/$input_filesystem" /mnt; then
    printf "${RED}  ERROR: Could not mount /dev/$input_filesystem${NC}\n"; exit 1; fi
mkdir -p /mnt/boot/efi
if ! run_logged mount "/dev/$input_efi" /mnt/boot/efi; then
    printf "${RED}  ERROR: Could not mount /dev/$input_efi${NC}\n"; exit 1; fi
[[ "$use_swap" == "yes" ]] && { run_logged swapon "/dev/$input_swap" || log_warn "swapon failed (non-fatal)"; }
log_info "Post-mount disk state:"; lsblk >> "$LOG_FILE"
printf "${GREEN}  Filesystems mounted.${NC}\n\n"

# ── Pacstrap ──────────────────────────────────────────────────────────────────
printf "${BOLD}  Pacstrapping base system (grab a coffee)...${NC}\n\n"
log_info "Starting pacstrap"
_PACSTRAP_PKGS=(base linux linux-firmware sof-firmware base-devel git grub efibootmgr nano networkmanager)
if ! run_tee pacstrap /mnt "${_PACSTRAP_PKGS[@]}"; then
    printf "${RED}  ERROR: pacstrap failed${NC}\n"; log_error "pacstrap failed"; exit 1; fi
printf '\n'

# ── fstab ────────────────────────────────────────────────────────────────────
printf "${BOLD}  Generating fstab...${NC}\n"
log_info "Generating fstab"
if ! genfstab -U /mnt >> /mnt/etc/fstab; then
    printf "${RED}  ERROR: genfstab failed${NC}\n"; log_error "genfstab failed"; exit 1; fi
log_info "fstab written"; printf "${GREEN}  fstab done.${NC}\n\n"

# =============================================================================
# WRITE CONFIG FILE (passed to second script via source)
# =============================================================================

log_info "Writing /mnt/install_config.sh"
{
    printf '#!/bin/bash\n# Auto-generated by arch install script — do not edit\n\n'
    printf 'INPUT_PARENT=%q\n'     "$input_parent"
    printf 'INPUT_EFI=%q\n'        "$input_efi"
    printf 'INPUT_SWAP=%q\n'       "$input_swap"
    printf 'USE_SWAP=%q\n'         "$use_swap"
    printf 'INPUT_FILESYSTEM=%q\n' "$input_filesystem"
    printf 'INPUT_SYSTEMNAME=%q\n' "$input_systemname"
    printf 'INPUT_USERNAME=%q\n'   "$input_username"
    printf 'INPUT_PASSWORD=%q\n'   "$input_password"
    printf 'ENABLE_ROOT=%q\n'      "$enable_root"
    printf 'ROOT_PASSWORD=%q\n'    "$root_password"
    printf 'KEYMAP=%q\n'           "$keymap"
    printf 'INSTALL_YAY=%q\n'      "$install_yay"
    printf 'INSTALL_SDDM=%q\n'     "$install_sddm"
    printf 'GPU_TYPE=%q\n'         "$gpu_type"
    printf 'DETECT_OS=%q\n'        "$detect_os"
    printf 'AUTOLOGIN=%q\n'        "$autologin"
    printf '\nSELECTED_LOCALES=('
    for _l in "${selected_locales[@]}"; do printf '%q ' "$_l"; done; printf ')\n'
    printf '\nOPTIONAL_PACKAGES=('
    for _p in "${optional_packages[@]}"; do printf '%q ' "$_p"; done; printf ')\n'
} > /mnt/install_config.sh
chmod 600 /mnt/install_config.sh  # passwords are in here, keep it tight
log_info "Config file written"

# =============================================================================
# WRITE SECOND SCRIPT
# =============================================================================

log_info "Writing /mnt/install_pt2.sh"
cat > /mnt/install_pt2.sh << 'ENDSCRIPT'
#!/bin/bash
# =============================================================================
#  Arch Install — Part 2 (inside chroot)
#  w-What? You're still here? Fine. Let's get this over with.
# =============================================================================

PT2_LOG="/var/log/arch_install_pt2.log"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; PINK='\033[1;35m'; NC='\033[0m'

INSTALL_ERRORS=()

_log2() { printf '[%s] [%-5s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >> "$PT2_LOG"; }
log_info()  { _log2 "INFO"  "$*"; printf "  ${GREEN}ok${NC}  %s\n" "$*"; }
log_warn()  { _log2 "WARN"  "$*"; printf "  ${YELLOW}warn${NC} %s\n" "$*"; }
log_error() { _log2 "ERROR" "$*"; printf "  ${RED}ERR${NC}  %s\n" "$*"; INSTALL_ERRORS+=("$*"); }
log_sep2()  { printf '%.0s─' {1..60} >> "$PT2_LOG"; printf '\n' >> "$PT2_LOG"; }

step() {
    local desc="$1"; shift
    _log2 "CMD" "[$desc] $*"
    local out; out=$("$@" 2>&1); local ret=$?
    printf '%s\n' "$out" >> "$PT2_LOG"
    [[ $ret -ne 0 ]] && log_error "Failed [$desc]" || _log2 "INFO" "Done [$desc]"
    return $ret
}

mkdir -p /var/log
{ printf '%.0s═' {1..60}; printf '\n Part 2 Install Log — %s\n' "$(date)"
  printf '%.0s═' {1..60}; printf '\n\n'; } > "$PT2_LOG"

# ── Load config ───────────────────────────────────────────────────────────────
source /install_config.sh 2>/dev/null || {
    printf "${RED}FATAL: /install_config.sh missing. Something went very wrong.${NC}\n"; exit 1; }
log_info "Config loaded"
log_sep2

# ── Timezone & clock ──────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}  Timezone & clock...${NC}\n"
step "timezone" ln -sf /usr/share/zoneinfo/America/Lima /etc/localtime
step "hwclock"  hwclock --systohc

# ── Keymap ───────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}  Keyboard layout...${NC}\n"
printf 'KEYMAP=%s\n' "$KEYMAP" > /etc/vconsole.conf \
    && log_info "Keymap set: $KEYMAP" \
    || log_error "Failed to write vconsole.conf"

# ── Locales ───────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}  Locales...${NC}\n"
for locale_str in "${SELECTED_LOCALES[@]}"; do
    escaped=$(printf '%s' "$locale_str" | sed 's/\./\\./g; s/\//\\\//g')
    if sed -i "s/^#\(${escaped}\)/\1/" /etc/locale.gen; then
        log_info "Uncommented: $locale_str"
    else
        log_error "Could not uncomment locale: $locale_str"
    fi
done
step "locale-gen" locale-gen
LANG_VALUE="${SELECTED_LOCALES[0]%% *}"
printf 'LANG=%s\n' "$LANG_VALUE" > /etc/locale.conf \
    && log_info "LANG=$LANG_VALUE" \
    || log_error "Failed to write locale.conf"

# ── Hostname ─────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}  Hostname...${NC}\n"
printf '%s\n' "$INPUT_SYSTEMNAME" > /etc/hostname \
    && log_info "Hostname: $INPUT_SYSTEMNAME" \
    || log_error "Failed to set hostname"

# ── Multilib ─────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}  Enabling multilib...${NC}\n"
if grep -q '^\[multilib\]' /etc/pacman.conf; then
    log_info "Multilib already enabled"
else
    if sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf; then
        log_info "Multilib enabled"
    else
        log_error "Failed to enable multilib (check /etc/pacman.conf)"
    fi
fi

# ── Sudoers ───────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}  Configuring sudo...${NC}\n"
if sed -i 's/^# \(%wheel ALL=(ALL:ALL) ALL\)/\1/' /etc/sudoers; then
    log_info "Wheel group sudoers enabled"
else
    log_error "Failed to uncomment wheel in /etc/sudoers"
fi

# ── User ─────────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}  Creating user: $INPUT_USERNAME...${NC}\n"
step "useradd" useradd -m -G wheel -s /bin/bash "$INPUT_USERNAME"
printf '%s:%s\n' "$INPUT_USERNAME" "$INPUT_PASSWORD" | chpasswd \
    && log_info "Password set for $INPUT_USERNAME" \
    || log_error "chpasswd failed for $INPUT_USERNAME"

# ── Root account ──────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}  Root account...${NC}\n"
if [[ "$ENABLE_ROOT" == "yes" ]]; then
    printf 'root:%s\n' "$ROOT_PASSWORD" | chpasswd \
        && log_info "Root password set" \
        || log_error "Failed to set root password"
else
    step "lock-root" passwd -l root
fi

# ── Pacman update ─────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}  Updating package databases...${NC}\n"
step "pacman-Syu" pacman -Syu --noconfirm

# ── NetworkManager ────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}  Enabling NetworkManager...${NC}\n"
step "nm-enable" systemctl enable NetworkManager

# ── GRUB ─────────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}  Installing GRUB...${NC}\n"
step "grub-install" grub-install "/dev/${INPUT_PARENT}"

if [[ "$DETECT_OS" == "yes" ]]; then
    printf "\n${BOLD}${CYAN}  Setting up OS detection...${NC}\n"
    step "os-prober" pacman -S --needed --noconfirm os-prober
    if sed -i 's/^#GRUB_DISABLE_OS_PROBER=false$/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub; then
        log_info "GRUB_DISABLE_OS_PROBER=false set"
    else
        log_warn "Could not find GRUB_DISABLE_OS_PROBER line — appending"
        echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
    fi
    DISK=$(lsblk -no PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null || printf '%s' "$INPUT_PARENT")
    for p in /dev/${DISK}[0-9]*; do
        [[ -b "$p" ]] || continue
        mkdir -p "/mnt/$(basename "$p")"
        mount "$p" "/mnt/$(basename "$p")" 2>/dev/null || true
    done
    log_info "Mounted partitions for os-prober"
fi

step "grub-mkconfig" grub-mkconfig -o /boot/grub/grub.cfg

# ── yay ───────────────────────────────────────────────────────────────────────
if [[ "$INSTALL_YAY" == "yes" ]]; then
    printf "\n${BOLD}${CYAN}  Installing yay...${NC}\n"
    # Temp NOPASSWD so makepkg can call sudo internally without a tty
    printf '%%wheel ALL=(ALL:ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/99-temp-nopasswd
    YAY_DIR="/home/${INPUT_USERNAME}/yay-bin"
    if step "yay-clone" sudo -u "$INPUT_USERNAME" git clone https://aur.archlinux.org/yay-bin.git "$YAY_DIR"; then
        cd "$YAY_DIR"
        if step "yay-makepkg" sudo -u "$INPUT_USERNAME" makepkg -si --noconfirm; then
            log_info "yay installed successfully"
        else
            log_error "yay makepkg/install failed"
        fi
        cd /; rm -rf "$YAY_DIR"
    else
        log_error "Failed to clone yay-bin"
    fi
    rm -f /etc/sudoers.d/99-temp-nopasswd
    log_info "Temp NOPASSWD rule removed"
fi

# ── SDDM ─────────────────────────────────────────────────────────────────────
if [[ "$INSTALL_SDDM" == "yes" ]]; then
    printf "\n${BOLD}${CYAN}  Installing SDDM...${NC}\n"
    step "sddm-install" pacman -S --needed --noconfirm sddm
    step "sddm-enable"  systemctl enable sddm
fi

# ── GPU drivers ───────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}  GPU drivers...${NC}\n"
case "$GPU_TYPE" in
    "intel")
        step "intel-gpu" pacman -S --needed --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel;;
    "rtx"|"gtx"|"athlon")
        log_warn "GPU type '$GPU_TYPE' driver not implemented yet. Skipping.";;
    *)
        log_info "No GPU drivers (none/broke boi)";;
esac

# ── Autologin ─────────────────────────────────────────────────────────────────
if [[ "$AUTOLOGIN" == "yes" ]]; then
    printf "\n${BOLD}${CYAN}  Setting up autologin...${NC}\n"
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null << EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${INPUT_USERNAME} --noclear %I \$TERM
EOF
    [[ $? -eq 0 ]] \
        && log_info "Autologin configured for $INPUT_USERNAME" \
        || log_error "Failed to write autologin override"
fi

# ── Optional packages ─────────────────────────────────────────────────────────
if [[ ${#OPTIONAL_PACKAGES[@]} -gt 0 ]]; then
    printf "\n${BOLD}${CYAN}  Installing optional packages...${NC}\n"
    step "optional-pkgs" pacman -S --needed --noconfirm "${OPTIONAL_PACKAGES[@]}"
fi

# ── Final report ──────────────────────────────────────────────────────────────
clear
printf "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}\n"
printf "${BOLD}${CYAN}║            Installation Complete!                ║${NC}\n"
printf "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}\n\n"

if [[ ${#INSTALL_ERRORS[@]} -eq 0 ]]; then
    printf "${GREEN}${BOLD}  Everything went clean.${NC}\n"
    printf "${PINK}  ...I-it's not like I'm proud of you or anything. Hmph.${NC}\n\n"
else
    printf "${YELLOW}${BOLD}  Some things had issues:${NC}\n\n"
    for _err in "${INSTALL_ERRORS[@]}"; do
        printf "  ${RED}x${NC} %s\n" "$_err"
    done
    printf "\n  ${DIM}Full details: $PT2_LOG${NC}\n\n"
fi

printf "${BOLD}  Install log saved to:${NC} %s\n" "$PT2_LOG"
printf "${DIM}  It'll sit there until YOU remove it. When you're confident:${NC}\n"
printf "  ${DIM}sudo rm %s${NC}\n\n" "$PT2_LOG"
printf "${PINK}${BOLD}  You can reboot now. And PLEASE don't break it again.${NC}\n"
printf "${PINK}  (I'm not doing this a 501st time.)${NC}\n\n"

log_sep2
log_info "Part 2 complete. Errors: ${#INSTALL_ERRORS[@]}"

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -f /install_config.sh
_log2 "INFO" "Config file removed"
# Self-delete
rm -f -- "$0"
ENDSCRIPT

chmod +x /mnt/install_pt2.sh
log_info "Second script written"

# =============================================================================
# ENTER CHROOT
# =============================================================================

printf '\n'
printf "${BOLD}${CYAN}  Entering the new system...${NC}\n"
printf "${PINK}  ...good luck in there. You'll need it.${NC}\n\n"
log_info "Launching arch-chroot"
log_sep

arch-chroot /mnt /install_pt2.sh

log_info "arch-chroot returned"
printf '\n'
printf "${BOLD}${GREEN}  Part 1 done! System installed.${NC}\n"
printf "${PINK}  Now reboot. And don't you dare reinstall Arch for at least a week.${NC}\n\n"