#!/data/data/com.termux/files/usr/bin/bash

# Stage Zero's SillyTavern Menu
# Designed for SillyTavern standalone installs in Termux.
# Backup scope: data/default-user + config.yaml, excluding secrets.json.

set -u

HELPER_VERSION="1.0.0"
ST_DIR="${ST_DIR:-$HOME/SillyTavern}"
HELPER_DIR="${HELPER_DIR:-$HOME/.stagezero-st}"
CONFIG_BACKUP_DIR="$HELPER_DIR/config-backups"
LAUNCHER_PATH="${PREFIX:-/data/data/com.termux/files/usr}/bin/st"
DOWNLOADS_DIR="$HOME/storage/downloads"
BACKUP_DIR="$DOWNLOADS_DIR/Stage Zero Backups"
RETURN_TO_MAIN=0

# สีของข้อความ Stage Zero เพื่อแยก UI ของ Helper ออกจาก log ปกติของ Termux/SillyTavern.
if [[ -t 1 && "${TERM:-dumb}" != "dumb" ]]; then
    C_RESET=$'\033[0m'
    C_TITLE=$'\033[1;36m'
    C_INFO=$'\033[36m'
    C_OK=$'\033[1;32m'
    C_WARN=$'\033[1;33m'
    C_ERR=$'\033[1;31m'
else
    C_RESET=''
    C_TITLE=''
    C_INFO=''
    C_OK=''
    C_WARN=''
    C_ERR=''
fi

infof() {
    printf '%b' "$C_INFO"
    builtin printf "$@"
    printf '%b' "$C_RESET"
}

okf() {
    printf '%b' "$C_OK"
    builtin printf "$@"
    printf '%b' "$C_RESET"
}

warnf() {
    printf '%b' "$C_WARN"
    builtin printf "$@"
    printf '%b' "$C_RESET"
}

errf() {
    printf '%b' "$C_ERR"
    builtin printf "$@"
    printf '%b' "$C_RESET"
}

promptf() {
    printf '%b' "$C_TITLE"
    builtin printf "$@"
    printf '%b' "$C_RESET"
}

mkdir -p "$HELPER_DIR" "$CONFIG_BACKUP_DIR" 2>/dev/null || true

line() {
    printf '%b' "$C_TITLE"
    printf '%*s\n' 40 '' | tr ' ' '='
    printf '%b' "$C_RESET"
}

main_header() {
    local title="Stage Zero's SillyTavern Menu"
    local width=40
    local pad=$(( (width - ${#title}) / 2 ))
    (( pad < 0 )) && pad=0
    line
    printf '%b' "$C_TITLE"
    printf '%*s%s\n' "$pad" '' "$title"
    printf '%b' "$C_RESET"
    line
}

screen_clear() {
    if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then
        clear
    fi
}

read_choice() {
    local __var="$1"
    if [[ -r /dev/tty ]]; then
        IFS= read -r "$__var" </dev/tty
    else
        IFS= read -r "$__var"
    fi
}

pause_screen() {
    local _pause
    promptf '\nกด Enter เพื่อกลับ...'
    read_choice _pause
}

is_termux() {
    [[ -n "${PREFIX:-}" && "${PREFIX:-}" == *"com.termux"* ]]
}

st_valid() {
    [[ -d "$ST_DIR" && -f "$ST_DIR/package.json" && -f "$ST_DIR/server.js" && -f "$ST_DIR/start.sh" ]]
}

ensure_st() {
    if ! st_valid; then
        printf 'ไม่พบการติดตั้ง SillyTavern ที่สมบูรณ์ใน:\n%s\n' "$ST_DIR"
        printf '\nให้รัน Stage Zero Installer ใหม่เพื่อแก้การติดตั้ง\n'
        return 1
    fi
    return 0
}

ensure_storage() {
    if [[ -d "$DOWNLOADS_DIR" && -w "$DOWNLOADS_DIR" ]]; then
        mkdir -p "$BACKUP_DIR" || return 1
        return 0
    fi

    printf 'Stage Zero ต้องใช้สิทธิ์เข้าถึงโฟลเดอร์ Downloads เพื่อเก็บ Backup\n\n'
    if command -v termux-setup-storage >/dev/null 2>&1; then
        termux-setup-storage >/dev/null 2>&1 || true
        printf 'ถ้า Android ถามสิทธิ์ ให้กดอนุญาต แล้วกลับมาที่ Termux\n'
        printf 'จากนั้นกด Enter เพื่อทำต่อ...'
        local _storage
        read_choice _storage
    fi

    if [[ ! -d "$DOWNLOADS_DIR" || ! -w "$DOWNLOADS_DIR" ]]; then
        printf '\nยังเข้าถึง Downloads ไม่ได้\n'
        printf 'กรุณาอนุญาตสิทธิ์ไฟล์ให้ Termux แล้วลองใหม่\n'
        return 1
    fi

    mkdir -p "$BACKUP_DIR" || return 1
}

backup_display_path() {
    local file="$1"
    case "$file" in
        "$BACKUP_DIR"/*)
            printf 'Download/Stage Zero Backups/%s\n' "$(basename "$file")"
            ;;
        "$DOWNLOADS_DIR"/*)
            printf 'Download/%s\n' "$(basename "$file")"
            ;;
        *)
            printf '%s\n' "$file"
            ;;
    esac
}

get_st_version() {
    if command -v node >/dev/null 2>&1 && [[ -f "$ST_DIR/package.json" ]]; then
        node -e "try{console.log(require('$ST_DIR/package.json').version || 'ไม่ทราบ')}catch(e){console.log('ไม่ทราบ')}" 2>/dev/null
    else
        printf 'ไม่ทราบ\n'
    fi
}

get_branch() {
    if [[ -d "$ST_DIR/.git" ]] && command -v git >/dev/null 2>&1; then
        git -C "$ST_DIR" branch --show-current 2>/dev/null || printf 'ไม่ทราบ\n'
    else
        printf 'ไม่ทราบ\n'
    fi
}

get_git_state() {
    if [[ ! -d "$ST_DIR/.git" ]] || ! command -v git >/dev/null 2>&1; then
        printf 'ไม่พบ Git repository\n'
        return
    fi

    if [[ -d "$ST_DIR/.git/rebase-merge" || -d "$ST_DIR/.git/rebase-apply" || -f "$ST_DIR/.git/MERGE_HEAD" ]]; then
        printf 'มีการอัปเดต/รวมไฟล์ค้างอยู่\n'
        return
    fi

    if [[ -n "$(git -C "$ST_DIR" status --porcelain 2>/dev/null)" ]]; then
        printf 'มีไฟล์ถูกแก้ไข\n'
    else
        printf 'ปกติ\n'
    fi
}

show_support_info() {
    screen_clear
    printf '%bข้อมูลสำหรับแจ้งปัญหา%b\n\n' "$C_TITLE" "$C_RESET"
    printf '%bStage Zero Helper:%b %s\n' "$C_INFO" "$C_RESET" "$HELPER_VERSION"
    printf '%bDevice:%b Android\n' "$C_INFO" "$C_RESET"
    printf '%bSillyTavern:%b %s\n' "$C_INFO" "$C_RESET" "$(get_st_version)"
    printf '%bBranch:%b %s\n' "$C_INFO" "$C_RESET" "$(get_branch)"
    if command -v node >/dev/null 2>&1; then
        printf '%bNode.js:%b %s\n' "$C_INFO" "$C_RESET" "$(node -v 2>/dev/null)"
    else
        printf '%bNode.js:%b ไม่พบ\n' "$C_INFO" "$C_RESET"
    fi
    printf '%bGit:%b %s\n' "$C_INFO" "$C_RESET" "$(get_git_state)"
    printf '\n%bคัดลอกข้อมูลด้านบนแล้วส่งในห้องสอบถาม ได้เลย%b\n' "$C_WARN" "$C_RESET"
    printf '%bเพิ่มข้อมูลโมเดล, พรีเซตที่ใช้, และปัญหาในโพสต์ด้วย%b\n' "$C_WARN" "$C_RESET"
    pause_screen
}

start_st() {
    screen_clear
    ensure_st || { pause_screen; return; }
    infof 'กำลังเปิด SillyTavern...\n\n'
    cd "$ST_DIR" || return
    bash start.sh
    printf '\nSillyTavern หยุดทำงานแล้ว\n'
    pause_screen
}

update_and_start() {
    screen_clear
    ensure_st || { pause_screen; return; }

    if [[ ! -d "$ST_DIR/.git" ]]; then
        printf 'การติดตั้งนี้ไม่มีข้อมูล Git จึงอัปเดตอัตโนมัติไม่ได้\n'
        printf 'ลองใช้เมนู 3: ST เปิดไม่ได้ / แก้ปัญหา\n'
        pause_screen
        return
    fi

    infof 'กำลังตรวจสอบและอัปเดต SillyTavern...\n\n'

    if https_stack_broken; then
        printf 'ตรวจพบส่วนเชื่อมต่อ HTTPS ของ Termux ไม่ตรงเวอร์ชัน กำลังซ่อม...\n'
        if ! sync_https_stack; then
            printf 'ซ่อม HTTPS ไม่สำเร็จ กรุณาใช้เมนู 3: ST เปิดไม่ได้ / แก้ปัญหา\n'
            pause_screen
            return
        fi
        okf '✓ ซ่อม HTTPS เรียบร้อย\n\n'
    fi

    if git -C "$ST_DIR" pull --rebase --autostash; then
        printf '\nอัปเดตเรียบร้อย กำลังเปิด SillyTavern...\n\n'
        cd "$ST_DIR" || return
        bash start.sh
        printf '\nSillyTavern หยุดทำงานแล้ว\n'
        pause_screen
    else
        printf '\nอัปเดตไม่สำเร็จ แต่ข้อมูลผู้ใช้ยังไม่ถูกลบ\n'
        printf '\n1. เปิด SillyTavern เวอร์ชันเดิมต่อ\n'
        printf '0. กลับเมนู\n\n'
        promptf 'เลือกเมนู: '
        local choice
        read_choice choice
        if [[ "$choice" == "1" ]]; then
            cd "$ST_DIR" || return
            bash start.sh
        fi
    fi
}

write_stagezero_apt_source() {
    local base="${1:-https://packages.termux.dev}"
    mkdir -p "$HELPER_DIR"
    printf 'deb %s/apt/termux-main stable main\n' "$base" > "$HELPER_DIR/termux-main.list"
}

apt_noninteractive() {
    local source_file="$HELPER_DIR/termux-main.list"
    [[ -f "$source_file" ]] || write_stagezero_apt_source "https://packages.termux.dev"

    DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none \
    apt-get \
        -o Dpkg::Use-Pty=0 \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        -o Dir::Etc::sourcelist="$source_file" \
        -o Dir::Etc::sourceparts="-" \
        "$@" </dev/null
}

prepare_stagezero_apt() {
    # Use a private APT source file so Stage Zero never changes the user's
    # Termux mirror settings. This also bypasses pkg's rotating mirror choice.
    write_stagezero_apt_source "https://packages.termux.dev"
    if apt_noninteractive update >/dev/null 2>&1; then
        return 0
    fi

    write_stagezero_apt_source "https://packages-cf.termux.dev"
    apt_noninteractive update >/dev/null 2>&1
}

https_stack_broken() {
    local check_file="$HELPER_DIR/.https-link-check-$$"
    : > "$check_file"

    if command -v curl >/dev/null 2>&1; then
        curl --version >>"$check_file" 2>&1 || true
    fi

    local remote_https="${PREFIX:-/data/data/com.termux/files/usr}/libexec/git-core/git-remote-https"
    if [[ -x "$remote_https" ]]; then
        "$remote_https" >>"$check_file" 2>&1 || true
    fi

    if grep -Eq 'CANNOT LINK EXECUTABLE|cannot locate symbol' "$check_file" 2>/dev/null; then
        rm -f "$check_file"
        return 0
    fi

    rm -f "$check_file"
    return 1
}

sync_https_stack() {
    prepare_stagezero_apt || return 1

    # curl/libcurl and git-remote-https are built against the current OpenSSL
    # in the Termux repository. Explicitly upgrade them together to avoid a
    # partial-upgrade ABI mismatch.
    apt_noninteractive install -y \
        openssl libngtcp2 libcurl curl ca-certificates git >/dev/null 2>&1 || return 1

    DEBIAN_FRONTEND=noninteractive \
        dpkg --force-confdef --force-confold --configure -a </dev/null >/dev/null 2>&1 || true

    if https_stack_broken; then
        apt_noninteractive install --reinstall -y \
            openssl libngtcp2 libcurl curl ca-certificates git >/dev/null 2>&1 || return 1
        DEBIAN_FRONTEND=noninteractive \
            dpkg --force-confdef --force-confold --configure -a </dev/null >/dev/null 2>&1 || true
    fi

    ! https_stack_broken
}

install_required_packages() {
    if ! is_termux; then
        return 0
    fi

    prepare_stagezero_apt || return 1

    # Finish an interrupted package configuration without prompting for
    # conffile choices. Keep the currently-installed config by default.
    DEBIAN_FRONTEND=noninteractive \
        dpkg --force-confdef --force-confold --configure -a </dev/null >/dev/null 2>&1 || true
    apt_noninteractive -f install -y >/dev/null 2>&1 || true

    # Repair mode is allowed to synchronize Termux packages. This prevents
    # partial upgrades such as a new libcurl with an old OpenSSL.
    apt_noninteractive full-upgrade -y >/dev/null 2>&1 || return 1

    apt_noninteractive install -y \
        git nodejs-lts nano zip unzip curl ca-certificates \
        openssl libngtcp2 libcurl >/dev/null 2>&1 || return 1

    sync_https_stack || return 1

    if command -v getconf >/dev/null 2>&1 && [[ "$(getconf LONG_BIT 2>/dev/null || true)" == "32" ]]; then
        apt_noninteractive install -y esbuild >/dev/null 2>&1 || true
    fi
}

repair_st() {
    screen_clear
    printf 'ST เปิดไม่ได้ / แก้ปัญหา\n\n'
    infof 'กำลังตรวจสอบและซ่อมอัตโนมัติ...\n\n'

    if ! install_required_packages; then
        errf '✗ ติดตั้งเครื่องมือที่จำเป็นไม่สำเร็จ\n'
        printf 'ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่\n'
        pause_screen
        return
    fi

    if ! st_valid; then
        errf '✗ พบว่าการติดตั้ง SillyTavern ไม่สมบูรณ์\n'
        printf 'เพื่อป้องกันข้อมูลหาย ระบบจะไม่ลบหรือเขียนทับโฟลเดอร์นี้อัตโนมัติ\n'
        printf 'ให้รัน Stage Zero Installer ใหม่เพื่อจัดการการติดตั้ง\n'
        pause_screen
        return
    fi

    okf '✓ เครื่องมือพื้นฐานครบ\n'

    if [[ -d "$ST_DIR/.git" ]]; then
        # Clear only interrupted Git operations; never hard-reset user files.
        git -C "$ST_DIR" rebase --abort >/dev/null 2>&1 || true
        git -C "$ST_DIR" merge --abort >/dev/null 2>&1 || true

        if git -C "$ST_DIR" pull --rebase --autostash; then
            okf '✓ Git / ไฟล์โปรแกรมปกติ\n'
        else
            warnf '⚠ อัปเดต Git ไม่สำเร็จ ระบบหยุดก่อนเพื่อไม่ลบไฟล์ที่คุณอาจแก้เอง\n'
        fi
    else
        warnf '⚠ ไม่พบ Git repository — ข้ามการซ่อมส่วนอัปเดต\n'
    fi

    infof 'กำลังติดตั้ง Node modules ใหม่...\n'
    if (
        cd "$ST_DIR" &&
        export NODE_ENV=production &&
        npm install --no-save --no-audit --no-fund --loglevel=error --no-progress --omit=dev --ignore-scripts
    ); then
        okf '✓ Node modules พร้อมใช้งาน\n'
    else
        errf '✗ ติดตั้ง Node modules ไม่สำเร็จ\n'
        printf 'ตรวจสอบอินเทอร์เน็ตและพื้นที่เครื่อง แล้วลองใหม่\n'
        pause_screen
        return
    fi

    if [[ ! -f "$ST_DIR/config.yaml" ]]; then
        (cd "$ST_DIR" && npm run init >/dev/null 2>&1) || true
    fi

    printf '\nซ่อมเสร็จแล้ว\n\n'
    printf '1. เปิด SillyTavern\n'
    printf '2. ข้อมูลสำหรับแจ้งปัญหา\n'
    printf '0. กลับ\n\n'
    promptf 'เลือกเมนู: '
    local choice
    read_choice choice
    case "$choice" in
        1) start_st ;;
        2) show_support_info ;;
    esac
}

troubleshoot_menu() {
    while true; do
        screen_clear
        printf 'ST เปิดไม่ได้ / แก้ปัญหา\n\n'
        printf 'ใช้เมนูนี้เมื่อ:\n'
        printf '%s\n' '- เปิด SillyTavern ไม่ได้'
        printf '%s\n' '- อัปเดตแล้วมี Error'
        printf '%s\n' '- หน้าเว็บไม่ขึ้น'
        printf '%s\n\n' '- เคยใช้ได้ แต่จู่ ๆ ใช้ไม่ได้'
        printf '1. ตรวจสอบและซ่อมอัตโนมัติ\n'
        printf '2. ข้อมูลสำหรับแจ้งปัญหา\n'
        printf '0. กลับ\n\n'
        promptf 'เลือกเมนู: '
        local choice
        read_choice choice
        case "$choice" in
            1) repair_st ;;
            2) show_support_info ;;
            0) return ;;
        esac
    done
}

create_backup() {
    local tag="${1:-Backup}"
    LAST_BACKUP_PATH=""

    ensure_storage || return 1
    ensure_st || return 1

    local has_data=0
    local has_config=0
    [[ -d "$ST_DIR/data/default-user" ]] && has_data=1
    [[ -f "$ST_DIR/config.yaml" ]] && has_config=1

    if (( has_data == 0 && has_config == 0 )); then
        printf 'ยังไม่มีข้อมูลสำหรับสำรอง\n'
        return 1
    fi

    local timestamp
    timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
    local backup_path="$BACKUP_DIR/StageZero_ST_${tag}_${timestamp}.zip"
    local n=2
    while [[ -e "$backup_path" ]]; do
        backup_path="$BACKUP_DIR/StageZero_ST_${tag}_${timestamp}_${n}.zip"
        ((n++))
    done
    local manifest_dir="$HELPER_DIR/.backup-manifest-$$"
    rm -rf "$manifest_dir"
    mkdir -p "$manifest_dir"

    cat > "$manifest_dir/stagezero-backup-info.txt" <<INFO
Stage Zero SillyTavern Backup
Helper-Version: $HELPER_VERSION
Created: $(date -Iseconds 2>/dev/null || date)
Includes: data/default-user and config.yaml when present
Excluded: secrets.json (API keys)
INFO

    local zip_args=()
    (( has_data == 1 )) && zip_args+=("data/default-user")
    (( has_config == 1 )) && zip_args+=("config.yaml")

    rm -f "$backup_path"
    if ! (
        cd "$ST_DIR" &&
        zip -qr "$backup_path" "${zip_args[@]}" \
            -x 'data/default-user/secrets.json' 'data/default-user/*/secrets.json'
    ); then
        rm -rf "$manifest_dir"
        rm -f "$backup_path"
        printf 'สร้าง Backup ไม่สำเร็จ\n'
        return 1
    fi

    if ! (cd "$manifest_dir" && zip -q "$backup_path" stagezero-backup-info.txt); then
        rm -rf "$manifest_dir"
        rm -f "$backup_path"
        printf 'สร้างข้อมูลกำกับ Backup ไม่สำเร็จ\n'
        return 1
    fi
    rm -rf "$manifest_dir"

    if ! unzip -tq "$backup_path" >/dev/null 2>&1; then
        rm -f "$backup_path"
        printf 'ตรวจสอบ ZIP ไม่ผ่าน จึงยกเลิก Backup เพื่อความปลอดภัย\n'
        return 1
    fi

    if unzip -Z1 "$backup_path" | grep -Eq '(^|/)secrets\.json$'; then
        rm -f "$backup_path"
        printf 'ตรวจพบ secrets.json ใน ZIP ระบบจึงลบ Backup นี้ทิ้งเพื่อป้องกัน API Key รั่ว\n'
        return 1
    fi

    LAST_BACKUP_PATH="$backup_path"
    return 0
}

backup_now() {
    screen_clear
    printf 'สร้าง Backup\n\n'
    printf 'จะสำรองข้อมูลบัญชี default-user และ config.yaml\n'
    printf 'ไม่รวม secrets.json / API Key\n'
    printf 'ไฟล์ ZIP จะถูกเก็บใน Downloads > Stage Zero Backups\n\n'

    if create_backup "Backup"; then
        okf '✓ สำรองข้อมูลเรียบร้อย\n\n'
        printf '%s\n' "$(backup_display_path "$LAST_BACKUP_PATH")"
        printf '\nหมายเหตุ: config.yaml อาจมีค่าการตั้งค่าเซิร์ฟเวอร์ส่วนตัว ควรเก็บ ZIP ไว้กับตัว\n'
    fi
    pause_screen
}

zip_is_safe() {
    local file="$1"
    local names
    names="$(unzip -Z1 "$file" 2>/dev/null)" || return 1

    # Reject absolute paths, parent traversal, or Windows-style path separators.
    if printf '%s\n' "$names" | grep -Eq '(^/|(^|/)\.\.(/|$)|\\)'; then
        return 1
    fi
    return 0
}

find_user_root() {
    local root="$1"

    if [[ -d "$root/data/default-user" ]]; then
        printf '%s\n' "$root/data/default-user"
        return 0
    fi
    if [[ -d "$root/default-user" ]]; then
        printf '%s\n' "$root/default-user"
        return 0
    fi
    if [[ -f "$root/settings.json" || -d "$root/characters" || -d "$root/chats" || -d "$root/worlds" ]]; then
        printf '%s\n' "$root"
        return 0
    fi

    local entries=()
    shopt -s nullglob dotglob
    entries=("$root"/*)
    shopt -u dotglob
    if (( ${#entries[@]} == 1 )) && [[ -d "${entries[0]}" ]]; then
        local only="${entries[0]}"
        if [[ -f "$only/settings.json" || -d "$only/characters" || -d "$only/chats" || -d "$only/worlds" ]]; then
            printf '%s\n' "$only"
            return 0
        fi
    fi

    return 1
}

restore_from_zip() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        printf 'ไม่พบไฟล์ Backup\n'
        return 1
    fi
    if ! unzip -tq "$file" >/dev/null 2>&1; then
        printf 'ZIP เสียหรืออ่านไม่ได้\n'
        return 1
    fi
    if ! zip_is_safe "$file"; then
        printf 'ZIP มี path ที่ไม่ปลอดภัย ระบบจึงไม่เปิดไฟล์นี้\n'
        return 1
    fi

    ensure_st || return 1

    local temp_dir="$HELPER_DIR/.restore-$$"
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    if ! unzip -qq "$file" -d "$temp_dir"; then
        rm -rf "$temp_dir"
        printf 'แตกไฟล์ Backup ไม่สำเร็จ\n'
        return 1
    fi

    local format="native"
    [[ -f "$temp_dir/stagezero-backup-info.txt" ]] && format="stagezero"

    local user_root
    if ! user_root="$(find_user_root "$temp_dir")"; then
        rm -rf "$temp_dir"
        printf 'ไม่พบข้อมูลบัญชี SillyTavern ใน ZIP นี้\n'
        return 1
    fi

    # Never import API keys, even from a native SillyTavern backup.
    rm -f "$user_root/secrets.json"

    if [[ -d "$ST_DIR/data/default-user" ]] && [[ -n "$(find "$ST_DIR/data/default-user" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
        infof 'กำลังสร้าง Backup ปัจจุบันก่อนกู้คืน...\n'
        if ! create_backup "PreRestore"; then
            rm -rf "$temp_dir"
            printf 'สร้าง Backup ก่อนกู้คืนไม่สำเร็จ ระบบจึงยกเลิก Restore\n'
            return 1
        fi
        okf '✓ เก็บข้อมูลเดิมไว้ที่:\n%s\n\n' "$(backup_display_path "$LAST_BACKUP_PATH")"
    fi

    local current_user="$ST_DIR/data/default-user"
    local old_user="$ST_DIR/data/.default-user-stagezero-old-$$"
    local secret_copy="$HELPER_DIR/.current-secrets-$$.json"
    rm -f "$secret_copy"
    if [[ -f "$current_user/secrets.json" ]]; then
        cp "$current_user/secrets.json" "$secret_copy" 2>/dev/null || true
    fi

    mkdir -p "$ST_DIR/data"
    rm -rf "$old_user"
    if [[ -d "$current_user" ]]; then
        mv "$current_user" "$old_user" || {
            rm -rf "$temp_dir"
            rm -f "$secret_copy"
            printf 'เตรียมโฟลเดอร์สำหรับ Restore ไม่สำเร็จ\n'
            return 1
        }
    fi

    mkdir -p "$current_user"
    if ! cp -a "$user_root"/. "$current_user"/; then
        rm -rf "$current_user"
        [[ -d "$old_user" ]] && mv "$old_user" "$current_user"
        rm -rf "$temp_dir"
        rm -f "$secret_copy"
        printf 'คัดลอกข้อมูลไม่สำเร็จ ระบบคืนข้อมูลเดิมให้แล้ว\n'
        return 1
    fi
    rm -f "$current_user/secrets.json"
    if [[ -f "$secret_copy" ]]; then
        cp "$secret_copy" "$current_user/secrets.json" 2>/dev/null || true
    fi

    if [[ "$format" == "stagezero" && -f "$temp_dir/config.yaml" ]]; then
        mkdir -p "$CONFIG_BACKUP_DIR"
        if [[ -f "$ST_DIR/config.yaml" ]]; then
            cp "$ST_DIR/config.yaml" "$CONFIG_BACKUP_DIR/config-before-restore-$(date '+%Y-%m-%d_%H-%M-%S').yaml" 2>/dev/null || true
        fi
        if ! cp "$temp_dir/config.yaml" "$ST_DIR/config.yaml"; then
            warnf '⚠ ข้อมูลผู้ใช้กู้คืนแล้ว แต่ config.yaml กู้คืนไม่สำเร็จ\n'
        fi
    fi

    rm -rf "$old_user" "$temp_dir"
    rm -f "$secret_copy"

    okf '✓ กู้คืนข้อมูลเรียบร้อย\n'
    if [[ "$format" == "stagezero" ]]; then
        okf '✓ กู้คืน config.yaml แล้ว (ถ้ามีใน Backup)\n'
    else
        printf 'ℹ เป็น SillyTavern User Backup จึงใช้ config.yaml ปัจจุบันต่อ\n'
    fi
    return 0
}

backup_zip_supported() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    unzip -tq "$file" >/dev/null 2>&1 || return 1
    zip_is_safe "$file" || return 1

    local names
    names="$(unzip -Z1 "$file" 2>/dev/null)" || return 1

    # Stage Zero backups have our marker plus a SillyTavern user-data tree.
    if printf '%s\n' "$names" | grep -Fxq 'stagezero-backup-info.txt' && \
       printf '%s\n' "$names" | grep -Eq '^data/default-user/(settings\.json|characters/|chats/|worlds/|themes/)'; then
        return 0
    fi

    # SillyTavern native "Download Backup" archives the user data folder.
    # Require settings.json AND at least one recognisable ST data directory under
    # the same optional outer folder. This prevents unrelated ZIPs in Downloads
    # from being offered as backups.
    local settings_path prefix
    while IFS= read -r settings_path; do
        [[ -n "$settings_path" ]] || continue
        prefix="${settings_path%settings.json}"
        if printf '%s\n' "$names" | grep -Eq "^${prefix//./\\.}(characters|chats|worlds|themes|backgrounds|groups|group chats|User Avatars|QuickReplies|extensions)/"; then
            return 0
        fi
    done < <(printf '%s\n' "$names" | grep -E '(^|/)settings\.json$' || true)

    return 1
}

collect_backup_files() {
    BACKUP_FILES=()
    ensure_storage || return 1

    shopt -s nullglob
    local f
    for f in "$BACKUP_DIR"/*.zip "$DOWNLOADS_DIR"/*.zip; do
        [[ -f "$f" ]] || continue
        backup_zip_supported "$f" || continue
        local duplicate=0
        local existing
        for existing in "${BACKUP_FILES[@]:-}"; do
            [[ "$existing" == "$f" ]] && duplicate=1 && break
        done
        (( duplicate == 0 )) && BACKUP_FILES+=("$f")
    done
    shopt -u nullglob
    return 0
}

post_restore_action() {
    while true; do
        printf '\nต้องการทำอะไรต่อ?\n\n'
        printf '1. เปิด SillyTavern\n'
        printf '2. อัปเดต + เปิด SillyTavern\n'
        printf '0. กลับ\n\n'
        promptf 'เลือกเมนู: '
        local choice
        read_choice choice
        case "$choice" in
            1) start_st; return ;;
            2) update_and_start; return ;;
            0) RETURN_TO_MAIN=1; return ;;
        esac
    done
}

restore_menu() {
    screen_clear
    printf 'กู้คืนจาก Backup\n\n'
    printf 'รองรับ:\n'
    printf '%s\n' '- Stage Zero Backup'
    printf '%s\n\n' '- SillyTavern User Backup (.zip)'
    printf 'API Key / secrets.json จะไม่ถูกนำเข้าจาก Backup\n\n'

    collect_backup_files || { pause_screen; return; }

    if (( ${#BACKUP_FILES[@]} == 0 )); then
        printf 'ไม่พบไฟล์ Backup ของ SillyTavern ใน Downloads\n'
        printf 'ให้นำ Stage Zero Backup หรือ SillyTavern User Backup ไปไว้ใน Download แล้วลองใหม่\n'
        pause_screen
        return
    fi

    local i=1
    local f
    for f in "${BACKUP_FILES[@]}"; do
        printf '%d. %s\n' "$i" "$(basename "$f")"
        ((i++))
    done
    printf '\n0. กลับ\n\n'
    promptf 'เลือกไฟล์: '
    local choice
    read_choice choice

    if [[ "$choice" == "0" ]]; then
        return
    fi
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#BACKUP_FILES[@]} )); then
        printf '\nตัวเลือกไม่ถูกต้อง\n'
        pause_screen
        return
    fi

    local selected="${BACKUP_FILES[choice-1]}"
    printf '\nเลือก: %s\n' "$(basename "$selected")"
    printf '\nการกู้คืนจะเปลี่ยนข้อมูล default-user ปัจจุบัน\n'
    printf 'ระบบจะสำรองข้อมูลปัจจุบันให้อัตโนมัติก่อน (ถ้ามี)\n\n'
    printf '1. กู้คืน\n'
    printf '0. ยกเลิก\n\n'
    promptf 'เลือกเมนู: '
    read_choice choice
    if [[ "$choice" == "1" ]]; then
        printf '\n'
        if restore_from_zip "$selected"; then
            post_restore_action
            return
        else
            pause_screen
        fi
    fi
}

backup_restore_menu() {
    while true; do
        screen_clear
        printf 'สำรองและกู้คืนข้อมูล\n\n'
        printf '1. สร้าง Backup\n'
        printf '2. กู้คืนจาก Backup\n'
        printf '0. กลับ\n\n'
        promptf 'เลือกเมนู: '
        local choice
        read_choice choice
        case "$choice" in
            1) backup_now; return ;;
            2)
                restore_menu
                if (( RETURN_TO_MAIN == 1 )); then
                    RETURN_TO_MAIN=0
                    return
                fi
                ;;
            0) return ;;
        esac
    done
}

ensure_config() {
    ensure_st || return 1
    if [[ ! -f "$ST_DIR/config.yaml" ]]; then
        printf 'ยังไม่พบ config.yaml กำลังสร้างไฟล์ตั้งค่า...\n'
        (cd "$ST_DIR" && npm run init >/dev/null 2>&1) || true
    fi
    [[ -f "$ST_DIR/config.yaml" ]]
}

edit_config() {
    screen_clear
    if ! ensure_config; then
        printf 'สร้าง config.yaml ไม่สำเร็จ ลองเปิด SillyTavern อย่างน้อยหนึ่งครั้งก่อน\n'
        pause_screen
        return
    fi

    local backup="$CONFIG_BACKUP_DIR/config-$(date '+%Y-%m-%d_%H-%M-%S').yaml"
    if ! cp "$ST_DIR/config.yaml" "$backup"; then
        printf 'สำรอง config ก่อนแก้ไม่สำเร็จ จึงยกเลิกเพื่อความปลอดภัย\n'
        pause_screen
        return
    fi

    printf 'สำรอง config ปัจจุบันเรียบร้อยแล้ว\n\n'
    printf 'วิธีบันทึกใน nano:\n'
    printf 'Ctrl + O  = บันทึก\n'
    printf 'Enter     = ยืนยันชื่อไฟล์\n'
    printf 'Ctrl + X  = ออก\n\n'
    promptf 'กด Enter เพื่อเปิด config.yaml...'
    local _edit
    read_choice _edit
    nano "$ST_DIR/config.yaml"
    printf '\nแก้ไขเสร็จแล้ว บางค่าต้องเปิด SillyTavern ใหม่จึงจะมีผล\n'
    pause_screen
}

restore_last_config() {
    screen_clear
    mkdir -p "$CONFIG_BACKUP_DIR"
    local latest
    latest="$(ls -1t "$CONFIG_BACKUP_DIR"/config-*.yaml 2>/dev/null | head -n 1 || true)"
    if [[ -z "$latest" || ! -f "$latest" ]]; then
        printf 'ยังไม่มี config ที่สำรองไว้ก่อนแก้\n'
        pause_screen
        return
    fi

    printf 'จะคืนค่า config จาก:\n%s\n\n' "$(basename "$latest")"
    printf '1. คืนค่า\n'
    printf '0. ยกเลิก\n\n'
    promptf 'เลือกเมนู: '
    local choice
    read_choice choice
    if [[ "$choice" == "1" ]]; then
        if [[ -f "$ST_DIR/config.yaml" ]]; then
            cp "$ST_DIR/config.yaml" "$CONFIG_BACKUP_DIR/config-before-rollback-$(date '+%Y-%m-%d_%H-%M-%S').yaml" 2>/dev/null || true
        fi
        if cp "$latest" "$ST_DIR/config.yaml"; then
            printf '\n✓ คืนค่า config เรียบร้อย\n'
        else
            printf '\n✗ คืนค่า config ไม่สำเร็จ\n'
        fi
        pause_screen
    fi
}

config_menu() {
    while true; do
        screen_clear
        printf 'ตั้งค่า config.yaml\n\n'
        printf '1. แก้ไข config.yaml\n'
        printf '2. คืนค่าก่อนแก้ครั้งล่าสุด\n'
        printf '0. กลับ\n\n'
        promptf 'เลือกเมนู: '
        local choice
        read_choice choice
        case "$choice" in
            1) edit_config ;;
            2) restore_last_config ;;
            0) return ;;
        esac
    done
}

uninstall_st() {
    screen_clear
    ensure_st || { pause_screen; return; }

    printf 'ถอนการติดตั้ง SillyTavern\n\n'
    printf 'ระบบจะ:\n'
    printf '%s\n' '- สำรอง default-user + config.yaml เป็น ZIP'
    printf '%s\n' '- ไม่รวม API Key / secrets.json'
    printf '%s\n' '- ตรวจสอบ ZIP ก่อนลบ'
    printf '%s\n' '- ลบ SillyTavern และ Stage Zero Helper'
    printf '%s\n\n' '- ไม่ลบ Termux, Node.js, Git หรือไฟล์ Backup'
    printf '1. สำรองข้อมูล + ถอนการติดตั้ง\n'
    printf '0. ยกเลิก\n\n'
    promptf 'เลือกเมนู: '
    local choice
    read_choice choice
    [[ "$choice" == "1" ]] || return

    printf '\nกำลังสร้าง Backup ก่อนถอนการติดตั้ง...\n'
    if ! create_backup "BeforeUninstall"; then
        printf '\nBackup ไม่สำเร็จ จึงยกเลิกการถอนการติดตั้ง\n'
        pause_screen
        return
    fi

    okf '✓ Backup ผ่านการตรวจสอบแล้ว:\n%s\n\n' "$(backup_display_path "$LAST_BACKUP_PATH")"
    printf 'ยืนยันอีกครั้ง:\n'
    printf '1. ลบ SillyTavern ตอนนี้\n'
    printf '0. ยกเลิก\n\n'
    promptf 'เลือกเมนู: '
    read_choice choice
    [[ "$choice" == "1" ]] || return

    # Safety guard: only remove the exact configured ST directory.
    if [[ "$ST_DIR" != "$HOME/SillyTavern" ]]; then
        printf '\nตำแหน่งติดตั้งไม่ใช่ค่ามาตรฐาน ระบบจึงไม่ลบอัตโนมัติเพื่อความปลอดภัย\n'
        pause_screen
        return
    fi

    rm -rf -- "$ST_DIR"

    # Restore any previous `st` executable that the installer preserved.
    if [[ -e "$HELPER_DIR/original-st-launcher" || -L "$HELPER_DIR/original-st-launcher" ]]; then
        rm -f -- "$LAUNCHER_PATH"
        cp -a "$HELPER_DIR/original-st-launcher" "$LAUNCHER_PATH" 2>/dev/null || true
    else
        rm -f -- "$LAUNCHER_PATH"
    fi

    # Re-enable a previous bash alias only if Stage Zero disabled it.
    if [[ -f "$HOME/.bashrc" ]] && grep -q '^# Stage Zero disabled previous st alias: ' "$HOME/.bashrc" 2>/dev/null; then
        local bashrc_tmp="$HELPER_DIR/.bashrc-restore-$$"
        sed 's/^# Stage Zero disabled previous st alias: //' "$HOME/.bashrc" > "$bashrc_tmp" && cat "$bashrc_tmp" > "$HOME/.bashrc"
        rm -f "$bashrc_tmp"
    fi


    printf '\n✓ ถอนการติดตั้ง SillyTavern เรียบร้อย\n'
    okf '✓ Backup ยังอยู่ใน Downloads > Stage Zero Backups\n'
    okf '✓ Termux ไม่ได้รับผลกระทบ\n\n'
    printf '%s\n' "$(backup_display_path "$LAST_BACKUP_PATH")"

    # The current shell has already loaded this script, so removing the helper is safe now.
    rm -rf -- "$HELPER_DIR"
    exit 0
}

main_menu() {
    while true; do
        screen_clear
        main_header
        printf '\n'
        printf '1. เปิด SillyTavern\n'
        printf '2. อัปเดต + เปิด SillyTavern\n'
        printf '3. ST เปิดไม่ได้ / แก้ปัญหา\n'
        printf '4. สำรองข้อมูล\n'
        printf '5. ตั้งค่า config.yaml\n'
        printf '6. ถอนการติดตั้ง SillyTavern\n'
        printf '\n0. ออก\n\n'
        promptf 'เลือกเมนู: '

        local choice
        read_choice choice
        case "$choice" in
            1) start_st ;;
            2) update_and_start ;;
            3) troubleshoot_menu ;;
            4) backup_restore_menu ;;
            5) config_menu ;;
            6) uninstall_st ;;
            0) exit 0 ;;
        esac
    done
}

case "${1:-}" in
    --restore)
        restore_menu
        if (( RETURN_TO_MAIN == 1 )); then
            RETURN_TO_MAIN=0
            main_menu
        fi
        ;;
    --start)
        start_st
        ;;
    --support)
        show_support_info
        ;;
    *)
        main_menu
        ;;
esac
