#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/bw_codex_issue.sh [options]

Pick one Beadwork issue, run Codex against it, verify, commit, close, and sync.

Options:
  --dry-run                 Print the selected issue and planned commands only.
  --issue ID                Run a specific Beadwork issue instead of selecting one.
  --model MODEL             Codex model to use. Default: $CODEX_MODEL or gpt-5.5.
  --profile PROFILE         Optional Codex config profile.
  --sandbox MODE            Codex sandbox mode. Default: workspace-write.
  --allow-epic              Allow selecting epic issues. Default: false.
  --strict-ready            Do not fall back from bw ready to bw list --all.
  --no-worktree             Run in the current checkout instead of a fresh worktree.
  --worktree-root DIR       Directory for created worktrees.
  --base REF                Base ref for new worktree branches. Default: current HEAD.
  --branch NAME             Explicit branch name. Default: bw/<issue-id>-<slug>.
  --reuse-worktree          Reuse an existing worktree path if it exists.
  --allow-dirty             Do not require the starting checkout to be clean.
  --no-sync                 Do not run bw sync after closing the issue.
  --no-close                Do not close the issue after committing.
  --no-verify               Skip verification.
  --verify-cmd CMD          Verification command. Default: $BW_CODEX_VERIFY_CMD or mix quality.
  --prompt-file FILE        Use a custom prompt file. Appends issue context.
  -h, --help                Show this help.

Hook environment variables:
  BW_CODEX_PREPARE_CMD      Runs after the worktree is ready, before bw start.
  BW_CODEX_PRE_CODEX_CMD    Runs after bw start, before Codex.
  BW_CODEX_REVIEW_CMD       Runs after Codex, before verification. Use this for another model.
  BW_CODEX_PRE_COMMIT_CMD   Runs after verification, before git add/commit.
  BW_CODEX_POST_COMMIT_CMD  Runs after commit, before bw close/sync.

Command customization:
  CODEX_MODEL               Default model when --model is not provided.
  CODEX_EXTRA_ARGS          Extra shell words appended to the default codex exec command.
  CODEX_COMMAND_TEMPLATE    Full command template. If set, it is evaluated with the prompt
                            on stdin and these variables exported:
                            ISSUE_ID ISSUE_TITLE ISSUE_TYPE ISSUE_JSON WORKDIR REPO_ROOT

Examples:
  scripts/bw_codex_issue.sh --dry-run
  scripts/bw_codex_issue.sh --model gpt-5.5 --issue jido_con-qgc.1
  BW_CODEX_REVIEW_CMD='codex exec review --model gpt-5.5 --cd "$WORKDIR"' \
    scripts/bw_codex_issue.sh --model gpt-5.5
  CODEX_COMMAND_TEMPLATE='codex exec --cd "$WORKDIR" -m gpt-5.5 -s workspace-write -a never -' \
    scripts/bw_codex_issue.sh
USAGE
}

log() {
  printf '==> %s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

quote_command() {
  printf '%q ' "$@"
  printf '\n'
}

run() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '+ ' >&2
    quote_command "$@" >&2
  else
    "$@"
  fi
}

run_shell_hook() {
  local label="$1"
  local command="$2"
  local workdir="$3"

  [[ -z "${command}" ]] && return 0

  log "Running hook: ${label}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '+ (cd %q && %s)\n' "${workdir}" "${command}" >&2
  else
    (cd "${workdir}" && eval "${command}")
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

git_clean_or_allowed() {
  local repo="$1"

  if [[ "${ALLOW_DIRTY}" == "true" ]]; then
    return 0
  fi

  if [[ -n "$(git -C "${repo}" status --porcelain)" ]]; then
    die "working tree is dirty. Commit/stash changes or pass --allow-dirty."
  fi
}

slugify() {
  tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' |
    cut -c 1-60
}

select_issue() {
  local filter
  local selected

  filter='
    def eligible:
      .status == "open"
      and (($allow_epic == "true") or (.type != "epic"));
    [ .[] | select(eligible) ][0].id // empty
  '

  selected="$(
    bw ready --json |
      jq -r --arg allow_epic "${ALLOW_EPIC}" "${filter}"
  )"

  if [[ -z "${selected}" && "${STRICT_READY}" != "true" ]]; then
    selected="$(
      bw list --all --json |
        jq -r --arg allow_epic "${ALLOW_EPIC}" "${filter}"
    )"
  fi

  [[ -n "${selected}" ]] || die "no eligible Beadwork issue found"
  printf '%s\n' "${selected}"
}

write_prompt() {
  local prompt_file="$1"
  local custom_prompt_file="$2"

  {
    if [[ -n "${custom_prompt_file}" ]]; then
      sed -n '1,$p' "${custom_prompt_file}"
      printf '\n\n---\n\n'
    fi

    cat <<PROMPT
You are implementing exactly one Beadwork issue in the jido_connect repo.

Issue:
- ID: ${ISSUE_ID}
- Type: ${ISSUE_TYPE}
- Title: ${ISSUE_TITLE}
- Description: ${ISSUE_DESCRIPTION}

Rules:
- Run \`bw prime\` first and keep the work scoped to ${ISSUE_ID}.
- Implement only this issue. Do not opportunistically implement sibling issues.
- Keep generated Jido adapters thin and provider logic inside provider modules.
- Follow existing Spark DSL, Zoi struct, Splode error, client, handler, and test patterns.
- If this issue needs a shared abstraction or scope clarification, stop and explain that in the final response instead of broadening the change.
- Do not commit, close the Beadwork issue, or run \`bw sync\`; this script handles that after verification.
- Leave the repository in a clean, committable state with focused tests.

Before finishing, run the narrowest useful verification for the changed package.
PROMPT
  } >"${prompt_file}"
}

run_codex() {
  local prompt_file="$1"
  local workdir="$2"

  log "Running Codex for ${ISSUE_ID}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    if [[ -n "${CODEX_COMMAND_TEMPLATE:-}" ]]; then
      printf '+ (cd %q && %s < %q)\n' "${workdir}" "${CODEX_COMMAND_TEMPLATE}" "${prompt_file}" >&2
    else
      {
        printf '+ codex exec --cd %q --model %q --sandbox %q --ask-for-approval never' \
          "${workdir}" "${CODEX_MODEL_VALUE}" "${CODEX_SANDBOX}"

        if [[ -n "${CODEX_PROFILE}" ]]; then
          printf ' --profile %q' "${CODEX_PROFILE}"
        fi

        if [[ -n "${CODEX_EXTRA_ARGS:-}" ]]; then
          printf ' %s' "${CODEX_EXTRA_ARGS}"
        fi

        printf ' - < %q\n' "${prompt_file}"
      } >&2
    fi

    return 0
  fi

  if [[ -n "${CODEX_COMMAND_TEMPLATE:-}" ]]; then
    (cd "${workdir}" && eval "${CODEX_COMMAND_TEMPLATE}" <"${prompt_file}")
    return $?
  fi

  local command=(codex exec --cd "${workdir}" --model "${CODEX_MODEL_VALUE}" --sandbox "${CODEX_SANDBOX}" --ask-for-approval never)

  if [[ -n "${CODEX_PROFILE}" ]]; then
    command+=(--profile "${CODEX_PROFILE}")
  fi

  if [[ -n "${CODEX_EXTRA_ARGS:-}" ]]; then
    # Intentionally shell-split so callers can pass arbitrary Codex CLI flags.
    local extra_args=()
    # shellcheck disable=SC2206
    extra_args=(${CODEX_EXTRA_ARGS})
    command+=("${extra_args[@]}")
  fi

  command+=(-)
  "${command[@]}" <"${prompt_file}"
}

DRY_RUN=false
ISSUE_ID=""
CODEX_MODEL_VALUE="${CODEX_MODEL:-gpt-5.5}"
CODEX_PROFILE=""
CODEX_SANDBOX="workspace-write"
ALLOW_EPIC=false
STRICT_READY=false
USE_WORKTREE=true
WORKTREE_ROOT=""
BASE_REF=""
BRANCH_NAME=""
REUSE_WORKTREE=false
ALLOW_DIRTY=false
SYNC_AFTER=true
CLOSE_AFTER=true
VERIFY=true
VERIFY_CMD="${BW_CODEX_VERIFY_CMD:-mix quality}"
CUSTOM_PROMPT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --issue)
      ISSUE_ID="${2:-}"
      [[ -n "${ISSUE_ID}" ]] || die "--issue requires an ID"
      shift 2
      ;;
    --model)
      CODEX_MODEL_VALUE="${2:-}"
      [[ -n "${CODEX_MODEL_VALUE}" ]] || die "--model requires a value"
      shift 2
      ;;
    --profile)
      CODEX_PROFILE="${2:-}"
      [[ -n "${CODEX_PROFILE}" ]] || die "--profile requires a value"
      shift 2
      ;;
    --sandbox)
      CODEX_SANDBOX="${2:-}"
      [[ -n "${CODEX_SANDBOX}" ]] || die "--sandbox requires a value"
      shift 2
      ;;
    --allow-epic)
      ALLOW_EPIC=true
      shift
      ;;
    --strict-ready)
      STRICT_READY=true
      shift
      ;;
    --no-worktree)
      USE_WORKTREE=false
      shift
      ;;
    --worktree-root)
      WORKTREE_ROOT="${2:-}"
      [[ -n "${WORKTREE_ROOT}" ]] || die "--worktree-root requires a directory"
      shift 2
      ;;
    --base)
      BASE_REF="${2:-}"
      [[ -n "${BASE_REF}" ]] || die "--base requires a ref"
      shift 2
      ;;
    --branch)
      BRANCH_NAME="${2:-}"
      [[ -n "${BRANCH_NAME}" ]] || die "--branch requires a name"
      shift 2
      ;;
    --reuse-worktree)
      REUSE_WORKTREE=true
      shift
      ;;
    --allow-dirty)
      ALLOW_DIRTY=true
      shift
      ;;
    --no-sync)
      SYNC_AFTER=false
      shift
      ;;
    --no-close)
      CLOSE_AFTER=false
      shift
      ;;
    --no-verify)
      VERIFY=false
      shift
      ;;
    --verify-cmd)
      VERIFY_CMD="${2:-}"
      [[ -n "${VERIFY_CMD}" ]] || die "--verify-cmd requires a command"
      shift 2
      ;;
    --prompt-file)
      CUSTOM_PROMPT_FILE="${2:-}"
      [[ -f "${CUSTOM_PROMPT_FILE}" ]] || die "--prompt-file must point to a file"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

require_command bw
require_command codex
require_command git
require_command jq

REPO_ROOT="$(git rev-parse --show-toplevel)"
BASE_REF="${BASE_REF:-HEAD}"
WORKTREE_ROOT="${WORKTREE_ROOT:-$(dirname "${REPO_ROOT}")/jido_connect_worktrees}"

log "Priming Beadwork"
bw prime >/dev/null

if [[ "${DRY_RUN}" == "true" && -n "$(git -C "${REPO_ROOT}" status --porcelain)" ]]; then
  log "Working tree is dirty; continuing because this is a dry run."
else
  git_clean_or_allowed "${REPO_ROOT}"
fi

if [[ -z "${ISSUE_ID}" ]]; then
  ISSUE_ID="$(select_issue)"
fi

ISSUE_JSON="$(bw show "${ISSUE_ID}" --json)"
ISSUE_TITLE="$(jq -r '.title' <<<"${ISSUE_JSON}")"
ISSUE_TYPE="$(jq -r '.type' <<<"${ISSUE_JSON}")"
ISSUE_DESCRIPTION="$(jq -r '.description // ""' <<<"${ISSUE_JSON}")"

if [[ "${ISSUE_TYPE}" == "epic" && "${ALLOW_EPIC}" != "true" ]]; then
  die "${ISSUE_ID} is an epic. Pass --allow-epic if you really want to run it."
fi

ISSUE_SLUG="$(printf '%s' "${ISSUE_TITLE}" | slugify)"
BRANCH_NAME="${BRANCH_NAME:-bw/${ISSUE_ID}-${ISSUE_SLUG}}"

if [[ "${USE_WORKTREE}" == "true" ]]; then
  WORKDIR="${WORKTREE_ROOT}/${ISSUE_ID}-${ISSUE_SLUG}"
else
  WORKDIR="${REPO_ROOT}"
fi

export ISSUE_ID ISSUE_TITLE ISSUE_TYPE ISSUE_DESCRIPTION ISSUE_JSON WORKDIR REPO_ROOT

log "Selected ${ISSUE_ID}: ${ISSUE_TITLE}"
log "Workdir: ${WORKDIR}"
log "Branch: ${BRANCH_NAME}"

if [[ "${DRY_RUN}" == "true" ]]; then
  log "Dry run enabled; no mutation will be performed."
fi

if [[ "${USE_WORKTREE}" == "true" ]]; then
  if [[ -e "${WORKDIR}" && "${REUSE_WORKTREE}" != "true" ]]; then
    die "worktree path already exists: ${WORKDIR}. Pass --reuse-worktree or choose another root."
  fi

  if [[ ! -e "${WORKDIR}" ]]; then
    run mkdir -p "${WORKTREE_ROOT}"
    run git -C "${REPO_ROOT}" worktree add -b "${BRANCH_NAME}" "${WORKDIR}" "${BASE_REF}"
  fi
else
  git_clean_or_allowed "${WORKDIR}"
fi

run_shell_hook "prepare" "${BW_CODEX_PREPARE_CMD:-}" "${WORKDIR}"

run bw start "${ISSUE_ID}"

run_shell_hook "pre-codex" "${BW_CODEX_PRE_CODEX_CMD:-}" "${WORKDIR}"

PROMPT_FILE="${WORKDIR}/.bw-codex-${ISSUE_ID}.md"

if [[ "${DRY_RUN}" == "true" ]]; then
  log "Prompt would be written to ${PROMPT_FILE}"
else
  write_prompt "${PROMPT_FILE}" "${CUSTOM_PROMPT_FILE}"
fi

run_codex "${PROMPT_FILE}" "${WORKDIR}"

if [[ "${DRY_RUN}" != "true" ]]; then
  rm -f "${PROMPT_FILE}"
fi

run_shell_hook "review" "${BW_CODEX_REVIEW_CMD:-}" "${WORKDIR}"

if [[ "${VERIFY}" == "true" ]]; then
  run_shell_hook "verify" "${VERIFY_CMD}" "${WORKDIR}"
fi

run_shell_hook "pre-commit" "${BW_CODEX_PRE_COMMIT_CMD:-}" "${WORKDIR}"

if [[ "${DRY_RUN}" != "true" && -z "$(git -C "${WORKDIR}" status --porcelain)" ]]; then
  die "Codex produced no working-tree changes."
fi

run git -C "${WORKDIR}" add -A
run git -C "${WORKDIR}" commit -m "${ISSUE_ID}: ${ISSUE_TITLE}" -m "Implemented from Beadwork issue ${ISSUE_ID}."

run_shell_hook "post-commit" "${BW_CODEX_POST_COMMIT_CMD:-}" "${WORKDIR}"

if [[ "${CLOSE_AFTER}" == "true" ]]; then
  if [[ "${DRY_RUN}" == "true" ]]; then
    run bw close "${ISSUE_ID}" --reason "Implemented by scripted Codex run"
  else
    COMMIT_SHA="$(git -C "${WORKDIR}" rev-parse --short HEAD)"
    run bw close "${ISSUE_ID}" --reason "Implemented in ${COMMIT_SHA}"
  fi
fi

if [[ "${SYNC_AFTER}" == "true" ]]; then
  run bw sync
fi

log "Done: ${ISSUE_ID}"
