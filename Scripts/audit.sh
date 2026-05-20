#!/usr/bin/env bash
#|---/ /+--------------------------------+---/ /|#
#|--/ /-| Audit local deploy vs repo     |--/ /-|#
#|-/ /--| Reports drift between repo     |-/ /--|#
#|/ /---| Configs/ and ~/ deployed files |/ /---|#
#|---/ /+--------------------------------+---/ /|#

set -u

scrDir="$(dirname "$(realpath "$0")")"
repoDir="$(dirname "${scrDir}")"
cfgRoot="${repoDir}/Configs"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Compare each file under ${cfgRoot} against its deployed counterpart in \$HOME,
report drift introduced after install (local edits / missing / new).

Options:
  -v, --verbose          show unified diff body for each modified file
  -f, --filter PATTERN   only check repo-relative paths matching grep -E PATTERN
                         (e.g. -f '\.local/share/bin' or -f wallbash)
  -m, --modified-only    suppress 'missing' entries, only show MOD
  -s, --summary          one-line summary (no per-file list)
      --fix              overwrite drifted home files with repo copy (repo wins).
                         touches only MOD + SYMLINK rows, never MISS.
                         backs up overwritten files to ~/.config/cfg_backups/audit-<ts>/
  -y, --yes              skip confirmation prompt in --fix mode
  -h, --help             this help

Exit code: 0 if no drift (or all fixes succeeded), 1 otherwise.
EOF
}

verbose=0
filter=''
modified_only=0
summary=0
do_fix=0
assume_yes=0

while [ $# -gt 0 ]; do
    case "$1" in
    -v | --verbose) verbose=1 ;;
    -f | --filter)
        filter="$2"
        shift
        ;;
    -m | --modified-only) modified_only=1 ;;
    -s | --summary) summary=1 ;;
    --fix) do_fix=1 ;;
    -y | --yes) assume_yes=1 ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
    shift
done

if [ ! -d "${cfgRoot}" ]; then
    echo "ERROR: ${cfgRoot} not found (run from a HyDE checkout)" >&2
    exit 2
fi

# colors (only when stdout is a tty)
if [ -t 1 ]; then
    C_MOD=$'\033[33m'
    C_MISS=$'\033[36m'
    C_LINK=$'\033[35m'
    C_OK=$'\033[32m'
    C_DIM=$'\033[2m'
    C_RST=$'\033[0m'
else
    C_MOD='' C_MISS='' C_LINK='' C_OK='' C_DIM='' C_RST=''
fi

mod_count=0
miss_count=0
link_count=0
checked=0

mod_files=()
miss_files=()
link_files=()

while IFS= read -r -d '' repoFile; do
    rel="${repoFile#"${cfgRoot}"/}"
    if [ -n "${filter}" ] && ! echo "${rel}" | grep -Eq "${filter}"; then
        continue
    fi
    homeFile="${HOME}/${rel}"
    checked=$((checked + 1))

    if [ -L "${repoFile}" ]; then
        # repo entry is a symlink; compare link targets if home is also a link
        if [ -L "${homeFile}" ]; then
            r_tgt="$(readlink "${repoFile}")"
            h_tgt="$(readlink "${homeFile}")"
            if [ "${r_tgt}" != "${h_tgt}" ]; then
                link_files+=("${rel}")
                link_count=$((link_count + 1))
            fi
        elif [ -e "${homeFile}" ]; then
            link_files+=("${rel} (repo=symlink, home=regular)")
            link_count=$((link_count + 1))
        else
            miss_files+=("${rel}")
            miss_count=$((miss_count + 1))
        fi
        continue
    fi

    if [ ! -e "${homeFile}" ]; then
        miss_files+=("${rel}")
        miss_count=$((miss_count + 1))
        continue
    fi

    if ! cmp -s "${repoFile}" "${homeFile}"; then
        mod_files+=("${rel}")
        mod_count=$((mod_count + 1))
    fi
done < <(find "${cfgRoot}" \( -type f -o -type l \) -print0 2>/dev/null)

print_section() {
    local label="$1" color="$2" arr_name="$3"
    eval "local count=\${#${arr_name}[@]}"
    [ "${count}" -eq 0 ] && return
    printf '%s%s%s (%d)%s\n' "${color}" "${label}" "${C_RST}" "${count}" ""
    eval "local files=(\"\${${arr_name}[@]}\")"
    for f in "${files[@]}"; do
        printf '  %s%s%s\n' "${color}" "${f}" "${C_RST}"
        if [ "${verbose}" = 1 ] && [ "${label}" = "MOD" ]; then
            diff -u "${cfgRoot}/${f}" "${HOME}/${f}" 2>/dev/null \
                | sed 's/^/    /' || true
        fi
    done
}

if [ "${summary}" = 1 ]; then
    printf 'audit: checked=%d  modified=%d  missing=%d  symlink-drift=%d\n' \
        "${checked}" "${mod_count}" "${miss_count}" "${link_count}"
else
    print_section "MOD" "${C_MOD}" mod_files
    print_section "SYMLINK" "${C_LINK}" link_files
    if [ "${modified_only}" = 0 ]; then
        print_section "MISS" "${C_MISS}" miss_files
    fi
    _t=$((mod_count + link_count))
    [ "${modified_only}" = 0 ] && _t=$((_t + miss_count))
    if [ "${_t}" -eq 0 ]; then
        printf '%sclean%s (%d checked, repo == \$HOME)\n' "${C_OK}" "${C_RST}" "${checked}"
    else
        printf '\n%schecked %d, drift: %d mod, %d miss, %d symlink%s\n' \
            "${C_DIM}" "${checked}" "${mod_count}" "${miss_count}" "${link_count}" "${C_RST}"
    fi
fi

drift_total=$((mod_count + link_count))
[ "${modified_only}" = 0 ] && drift_total=$((drift_total + miss_count))

if [ "${do_fix}" = 1 ]; then
    fix_total=$((mod_count + link_count))
    if [ "${fix_total}" -eq 0 ]; then
        echo "nothing to fix."
        exit 0
    fi

    bkpDir="${HOME}/.config/cfg_backups/audit-$(date +'%y%m%d_%Hh%Mm%Ss')"
    echo
    printf '%s--fix%s will overwrite %d file(s) with repo copy.\n' "${C_MOD}" "${C_RST}" "${fix_total}"
    printf 'backup target: %s\n' "${bkpDir}"

    if [ "${assume_yes}" = 0 ]; then
        printf 'proceed? [y/N] '
        read -r ans
        case "${ans}" in
        y | Y | yes | YES) ;;
        *)
            echo "aborted."
            exit 1
            ;;
        esac
    fi

    mkdir -p "${bkpDir}"
    fix_fail=0

    apply_one() {
        local rel="$1"
        local src="${cfgRoot}/${rel}"
        local dst="${HOME}/${rel}"
        local bkp="${bkpDir}/${rel}"
        mkdir -p "$(dirname "${bkp}")" "$(dirname "${dst}")"
        if [ -e "${dst}" ] || [ -L "${dst}" ]; then
            cp -a "${dst}" "${bkp}" 2>/dev/null || true
        fi
        # symlink in repo → recreate as symlink
        if [ -L "${src}" ]; then
            rm -f "${dst}"
            if ln -s "$(readlink "${src}")" "${dst}"; then
                printf '  %s[fix]%s %s\n' "${C_OK}" "${C_RST}" "${rel}"
                return 0
            fi
        elif cp -a "${src}" "${dst}"; then
            printf '  %s[fix]%s %s\n' "${C_OK}" "${C_RST}" "${rel}"
            return 0
        fi
        printf '  %s[FAIL]%s %s\n' "${C_MOD}" "${C_RST}" "${rel}"
        return 1
    }

    for rel in "${mod_files[@]}"; do
        apply_one "${rel}" || fix_fail=$((fix_fail + 1))
    done
    for rel in "${link_files[@]}"; do
        # strip trailing annotation like " (repo=symlink, home=regular)"
        clean="${rel% (*}"
        apply_one "${clean}" || fix_fail=$((fix_fail + 1))
    done

    echo
    if [ "${fix_fail}" -eq 0 ]; then
        printf '%sapplied %d file(s)%s. backups at %s\n' \
            "${C_OK}" "${fix_total}" "${C_RST}" "${bkpDir}"
        exit 0
    else
        printf '%s%d of %d fix(es) failed%s. backups at %s\n' \
            "${C_MOD}" "${fix_fail}" "${fix_total}" "${C_RST}" "${bkpDir}"
        exit 1
    fi
fi

if [ "${drift_total}" -gt 0 ]; then
    exit 1
fi
exit 0
