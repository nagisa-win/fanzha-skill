#!/usr/bin/env bash
set -euo pipefail

REPO="nagisa-win/fanzha-skill"
REPO_URL="https://github.com/${REPO}.git"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${CYAN}[INFO]${RESET}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${RESET}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*"; }
err()   { printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2; }

cleanup() {
    if [[ -n "${TMPDIR:-}" && -d "${TMPDIR}" ]]; then
        rm -rf "${TMPDIR}"
    fi
}
trap cleanup EXIT

make_temp_dir() {
    TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/fanzha-skill.XXXXXX")"
}

detect_platform() {
    local os arch
    os="$(uname -s 2>/dev/null || echo Unknown)"
    arch="$(uname -m 2>/dev/null || echo Unknown)"
    printf "%s/%s" "${os}" "${arch}"
}

has_git()   { command -v git >/dev/null 2>&1; }
has_curl()  { command -v curl >/dev/null 2>&1; }
has_wget()  { command -v wget >/dev/null 2>&1; }

download_repo() {
    local dest="$1"
    if has_git; then
        info "使用 git clone 下载..."
        git clone --depth 1 "${REPO_URL}" "${dest}" 2>/dev/null
    elif has_curl; then
        info "使用 curl 下载 zip..."
        local zip_url="https://github.com/${REPO}/archive/refs/heads/master.zip"
        curl -fsSL "${zip_url}" -o "${dest}/repo.zip"
        (cd "${dest}" && unzip -q repo.zip && rm -f repo.zip)
        mv "${dest}/fanzha-skill-master" "${dest}/repo" 2>/dev/null || true
        if [[ -d "${dest}/repo" ]]; then
            cp -r "${dest}/repo/"* "${dest}/" 2>/dev/null || true
            cp -r "${dest}/repo/".[!.]* "${dest}/" 2>/dev/null || true
            rm -rf "${dest}/repo"
        fi
    elif has_wget; then
        info "使用 wget 下载 zip..."
        local zip_url="https://github.com/${REPO}/archive/refs/heads/master.zip"
        wget -q "${zip_url}" -O "${dest}/repo.zip"
        (cd "${dest}" && unzip -q repo.zip && rm -f repo.zip)
        mv "${dest}/fanzha-skill-master" "${dest}/repo" 2>/dev/null || true
        if [[ -d "${dest}/repo" ]]; then
            cp -r "${dest}/repo/"* "${dest}/" 2>/dev/null || true
            cp -r "${dest}/repo/".[!.]* "${dest}/" 2>/dev/null || true
            rm -rf "${dest}/repo"
        fi
    else
        err "需要 git、curl 或 wget 其中之一来下载仓库"
        exit 1
    fi
}

install_to() {
    local target="$1"
    local src="$2"
    local claude_dir="${target}/.claude"

    mkdir -p "${claude_dir}/skills/反诈/references"
    mkdir -p "${claude_dir}/rules"

    cp -r "${src}/skills/反诈/"* "${claude_dir}/skills/反诈/"
    cp -r "${src}/skills/反诈/references/"* "${claude_dir}/skills/反诈/references/"
    cp "${src}/rules/反诈-guard.md" "${claude_dir}/rules/反诈-guard.md"

    ok "已安装到 ${claude_dir}"
}

install_global() {
    local src="$1"
    local home_dir="${HOME}"
    if [[ -z "${home_dir}" || ! -d "${home_dir}" ]]; then
        err "无法确定 HOME 目录"
        exit 1
    fi
    install_to "${home_dir}" "${src}"
    ok "全局安装完成 — 所有 Claude Code 项目将自动生效"
}

install_project() {
    local src="$1"
    local target_dir

    if [[ -n "${FANZHA_PROJECT_DIR:-}" ]]; then
        target_dir="${FANZHA_PROJECT_DIR}"
    else
        target_dir="$(pwd)"
    fi

    if [[ ! -f "${target_dir}/.claude" && ! -d "${target_dir}/.claude" ]]; then
        info "当前目录 ${target_dir} 未检测到 .claude 目录，将自动创建"
    fi

    install_to "${target_dir}" "${src}"
    ok "项目级安装完成 — 仅在 ${target_dir} 下生效"
}

print_banner() {
    printf "\n"
    printf "${BOLD}  🛡️  反诈守护 Skill 安装器${RESET}\n"
    printf "${BOLD}  ━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    printf "  平台: %s\n\n" "$(detect_platform)"
}

print_result() {
    printf "\n"
    printf "${BOLD}  ━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    printf "${GREEN}${BOLD}  安装成功！${RESET}\n\n"
    printf "  接下来：\n"
    printf "  1. 在项目目录启动 Claude Code / Ducc\n"
    printf "  2. Skill 和 Rule 将自动加载\n"
    printf "  3. 尝试发送「反诈检查」测试\n\n"
    printf "  手动触发关键词：\n"
    printf "  反诈检查 / 帮我检查是否是诈骗 / 这是真的吗\n"
    printf "  感觉被骗了 / 有点可疑 / 核实一下 / 举报诈骗\n"
    printf "\n"
}

main() {
    print_banner

    local mode="${1:-}"

    if [[ -z "${mode}" ]]; then
        printf "  选择安装模式：\n"
        printf "    ${BOLD}1)${RESET} 全局安装（推荐，所有项目生效）\n"
        printf "    ${BOLD}2)${RESET} 项目级安装（仅当前目录生效）\n"
        printf "\n"
        read -rp "  请输入 [1/2]: " choice </dev/tty
        case "${choice}" in
            1) mode="global" ;;
            2) mode="project" ;;
            *) err "无效选择"; exit 1 ;;
        esac
    fi

    case "${mode}" in
        global|g) mode="global" ;;
        project|p) mode="project" ;;
        *)
            err "用法: install.sh [global|project]"
            err "  global  — 安装到 ~/.claude（所有项目生效）"
            err "  project — 安装到当前目录/.claude（仅当前项目生效）"
            exit 1
            ;;
    esac

    make_temp_dir
    info "下载 fanzha-skill 仓库..."
    download_repo "${TMPDIR}"

    if [[ ! -d "${TMPDIR}/skills/反诈" ]]; then
        err "下载的仓库结构异常，未找到 skills/反诈 目录"
        exit 1
    fi

    info "执行${mode}安装..."
    case "${mode}" in
        global)  install_global "${TMPDIR}" ;;
        project) install_project "${TMPDIR}" ;;
    esac

    print_result
}

main "$@"
