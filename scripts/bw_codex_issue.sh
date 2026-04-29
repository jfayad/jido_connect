#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/bw_codex_issue.sh [options]

Pick one Beadwork issue, run Codex against it, verify, commit, close, and sync.
By default this uses the current checkout. Worktrees/branches are opt-in.

Options:
  --dry-run                 Print the selected issue and planned commands only.
  --issue ID                Run a specific Beadwork issue instead of selecting one.
  --model MODEL             Codex model to use. Default: $CODEX_MODEL or gpt-5.5.
  --effort EFFORT           Codex reasoning effort: low, medium, high, xhigh.
                            Default: $CODEX_EFFORT, $CODEX_REASONING_EFFORT, or low.
  --profile PROFILE         Optional Codex config profile.
  --sandbox MODE            Codex sandbox mode. Default: workspace-write.
  --allow-epic              Allow selecting epic issues. Default: false.
  --strict-ready            Do not fall back from bw ready to bw list --all.
  --order ORDER             Queue order: priority, oldest, newest. Default: priority.
  --worktree                Run in a fresh/reused git worktree instead of the current checkout.
  --no-worktree             Backward-compatible no-op; current checkout is already the default.
  --worktree-root DIR       Directory for created worktrees.
  --base REF                Base ref for new worktree branches. Default: current HEAD.
  --branch NAME             Explicit branch name. Default: bw/<issue-id>-<slug>.
  --reuse-worktree          Backward-compatible no-op; existing worktrees are reused by default.
  --fresh-worktree          Fail if the target worktree path already exists.
  --allow-dirty             Do not require the starting checkout to be clean.
  --commit-all-dirty        Allow committing all dirty changes when --allow-dirty is used.
  --no-sync                 Do not run bw sync after closing the issue.
  --no-close                Do not close the issue after committing.
  --no-format               Skip the formatter phase.
  --format-cmd CMD          Formatter command. Default: $BW_CODEX_FORMAT_CMD or mix format.
  --no-verify               Skip verification.
  --verify-cmd CMD          Verification command. Default: $BW_CODEX_VERIFY_CMD or mix quality.
  --prompt-file FILE        Optional operator note appended after Beadwork context.
  -h, --help                Show this help.

Hook script environment variables:
  BW_CODEX_PREPARE_SCRIPT   Executable script path. Runs after checkout setup.
  BW_CODEX_PRE_CODEX_SCRIPT Executable script path. Runs after bw start, before Codex.
  BW_CODEX_REVIEW_SCRIPT    Executable script path. Runs after Codex, before verification.
  BW_CODEX_PRE_COMMIT_SCRIPT
                            Executable script path. Runs after verification, before commit.
  BW_CODEX_POST_COMMIT_SCRIPT
                            Executable script path. Runs after commit, before bw close/sync.

Trusted raw command hook environment variables:
  BW_CODEX_PREPARE_CMD      Runs after the worktree is ready, before bw start.
  BW_CODEX_PRE_CODEX_CMD    Runs after bw start, before Codex.
  BW_CODEX_REVIEW_CMD       Runs after Codex, before verification. Use this for another model.
  BW_CODEX_PRE_COMMIT_CMD   Runs after verification, before git add/commit.
  BW_CODEX_POST_COMMIT_CMD  Runs after commit, before bw close/sync.
                            Raw command hooks are eval'd. Use only trusted input.

Command customization:
  CODEX_MODEL               Default model when --model is not provided.
  CODEX_EFFORT              Default reasoning effort when --effort is not provided.
  CODEX_REASONING_EFFORT    Alternate env name for default reasoning effort.
  BW_CODEX_ORDER            Default issue order when --order is not provided.
  BW_CODEX_FORMAT_CMD       Default formatter command when --format-cmd is not provided.
  CODEX_EXTRA_ARGS          Extra shell words appended to the default codex exec command.
  CODEX_COMMAND_TEMPLATE    Full command template. If set, it is evaluated with the prompt
                            on stdin and these variables exported:
                            ISSUE_ID ISSUE_TITLE ISSUE_TYPE ISSUE_JSON WORKDIR REPO_ROOT
                            This is trusted shell code; prefer hook scripts when possible.

Examples:
  scripts/bw_codex_issue.sh --dry-run
  scripts/bw_codex_issue.sh --model gpt-5.5 --effort low --issue jido_con-qgc.1
  scripts/bw_codex_issue.sh --worktree --model gpt-5.5 --effort high --issue jido_con-qgc.1
  BW_CODEX_REVIEW_CMD='codex exec review --model gpt-5.5 --cd "$WORKDIR"' \
    scripts/bw_codex_issue.sh --model gpt-5.5
  CODEX_COMMAND_TEMPLATE='codex --ask-for-approval never exec --cd "$WORKDIR" -m gpt-5.5 -c model_reasoning_effort=\"low\" -s workspace-write -' \
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

validate_effort() {
  case "$1" in
    low | medium | high | xhigh)
      ;;
    *)
      die "invalid --effort '$1'. Expected one of: low, medium, high, xhigh."
      ;;
  esac
}

validate_order() {
  case "$1" in
    priority | oldest | newest)
      ;;
    *)
      die "invalid --order '$1'. Expected one of: priority, oldest, newest."
      ;;
  esac
}

run() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '+ ' >&2
    quote_command "$@" >&2
  else
    "$@"
  fi
}

run_script_hook() {
  local label="$1"
  local script="$2"
  local workdir="$3"

  [[ -z "${script}" ]] && return 0
  [[ -f "${script}" ]] || die "${label} hook script does not exist: ${script}"
  [[ -x "${script}" ]] || die "${label} hook script is not executable: ${script}"

  log "Running script hook: ${label}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '+ (cd %q && %q)\n' "${workdir}" "${script}" >&2
  else
    (cd "${workdir}" && "${script}")
  fi
}

run_shell_hook() {
  local label="$1"
  local command="$2"
  local workdir="$3"

  [[ -z "${command}" ]] && return 0

  log "Running trusted raw command hook: ${label}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '+ (cd %q && %s)\n' "${workdir}" "${command}" >&2
  else
    (cd "${workdir}" && eval "${command}")
  fi
}

run_hook() {
  local label="$1"
  local script="$2"
  local command="$3"
  local workdir="$4"

  run_script_hook "${label}" "${script}" "${workdir}"
  run_shell_hook "${label}" "${command}" "${workdir}"
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

git_status_snapshot() {
  local repo="$1"

  git -C "${repo}" status --porcelain | LC_ALL=C sort
}

dirty_baseline_path() {
  local issue_id="$1"

  mktemp "${TMPDIR:-/tmp}/bw-codex-${issue_id}-baseline.XXXXXX"
}

prompt_path() {
  local issue_id="$1"

  printf '%s/bw-codex-%s.md\n' "${TMPDIR:-/tmp}" "${issue_id}"
}

prompt_temp_path() {
  local issue_id="$1"

  mktemp "${TMPDIR:-/tmp}/bw-codex-${issue_id}.XXXXXX"
}

record_dirty_baseline() {
  local repo="$1"

  DIRTY_BASELINE_FILE="$(dirty_baseline_path "${ISSUE_ID}")"
  git_status_snapshot "${repo}" >"${DIRTY_BASELINE_FILE}"

  if [[ -s "${DIRTY_BASELINE_FILE}" && "${COMMIT_ALL_DIRTY}" != "true" ]]; then
    die "working tree has preexisting changes. Commit/stash them, or pass --commit-all-dirty with --allow-dirty."
  fi
}

cleanup_baseline() {
  if [[ -n "${DIRTY_BASELINE_FILE}" && -f "${DIRTY_BASELINE_FILE}" ]]; then
    rm -f "${DIRTY_BASELINE_FILE}"
  fi
}

stage_changes() {
  local workdir="$1"

  if [[ -z "${DIRTY_BASELINE_FILE}" || "${COMMIT_ALL_DIRTY}" == "true" || ! -s "${DIRTY_BASELINE_FILE}" ]]; then
    run git -C "${workdir}" add -A
    return 0
  fi

  die "refusing to stage changes on top of a dirty baseline without --commit-all-dirty"
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
      (.status == "in_progress" or .status == "open")
      and (($allow_epic == "true") or (.type != "epic"));
    def ordered:
      if $order == "oldest" then sort_by(.created, .id)
      elif $order == "newest" then sort_by(.created, .id) | reverse
      else sort_by((if .status == "in_progress" then 0 else 1 end), .priority, .created, .id)
      end;
    [ .[] | select(eligible) ] | ordered | .[0].id // empty
  '

  selected="$(
    bw ready --json |
      jq -r --arg allow_epic "${ALLOW_EPIC}" --arg order "${QUEUE_ORDER}" "${filter}"
  )"

  if [[ -z "${selected}" && "${STRICT_READY}" != "true" ]]; then
    selected="$(
      bw list --all --json |
        jq -r --arg allow_epic "${ALLOW_EPIC}" --arg order "${QUEUE_ORDER}" "${filter}"
    )"
  fi

  [[ -n "${selected}" ]] || die "no eligible Beadwork issue found"
  printf '%s\n' "${selected}"
}

issue_status() {
  bw show "$1" --json | jq -r '.status'
}

issue_commit_sha() {
  local workdir="$1"

  git -C "${workdir}" log -n 1 --format=%H --grep="^${ISSUE_ID}:" HEAD -- 2>/dev/null || true
}

start_issue_if_needed() {
  local status

  status="$(issue_status "${ISSUE_ID}")"

  case "${status}" in
    open)
      run bw start "${ISSUE_ID}"
      ;;
    in_progress)
      log "${ISSUE_ID} is already in_progress; continuing."
      ;;
    closed)
      log "${ISSUE_ID} is already closed; nothing to do."
      exit 0
      ;;
    *)
      die "${ISSUE_ID} has status '${status}', not open/in_progress."
      ;;
  esac
}

finish_issue() {
  local commit_sha="$1"
  local status

  if [[ "${CLOSE_AFTER}" == "true" ]]; then
    status="$(issue_status "${ISSUE_ID}")"

    if [[ "${status}" == "closed" ]]; then
      log "${ISSUE_ID} is already closed."
    elif [[ "${DRY_RUN}" == "true" ]]; then
      run bw close "${ISSUE_ID}" --reason "Implemented by scripted Codex run"
    else
      run bw close "${ISSUE_ID}" --reason "Implemented in ${commit_sha}"
    fi
  fi

  if [[ "${SYNC_AFTER}" == "true" ]]; then
    run bw sync
  fi
}

write_prompt() {
  local prompt_file="$1"
  local custom_prompt_file="$2"
  local issue_context

  issue_context="$(bw show "${ISSUE_ID}" --only description,comments)"

  {
    cat <<PROMPT
Implement the Beadwork issue below. Treat the Beadwork issue as the source of truth
for scope and acceptance. Keep the change limited to this issue.

The shell orchestrator will handle git commit, issue close, and sync after your
work is complete. Do not commit, close the issue, or run \`bw sync\`.

Run \`bw prime\` first, inspect the local code needed for this issue, implement the
smallest coherent change, and run the narrowest useful verification.

## Beadwork Issue JSON

\`\`\`json
${ISSUE_JSON}
\`\`\`

## Beadwork Issue Context

\`\`\`text
${issue_context}
\`\`\`
PROMPT

    if [[ -n "${custom_prompt_file}" ]]; then
      printf '\n## Operator Note\n\n'
      sed -n '1,$p' "${custom_prompt_file}"
      printf '\n'
    fi
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
        printf '+ codex --ask-for-approval never exec --cd %q --model %q -c %q --sandbox %q' \
          "${workdir}" \
          "${CODEX_MODEL_VALUE}" \
          "model_reasoning_effort=\"${CODEX_EFFORT_VALUE}\"" \
          "${CODEX_SANDBOX}"

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

  local command=(
    codex
    --ask-for-approval never
    exec
    --cd "${workdir}"
    --model "${CODEX_MODEL_VALUE}"
    -c "model_reasoning_effort=\"${CODEX_EFFORT_VALUE}\""
    --sandbox "${CODEX_SANDBOX}"
  )

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
CODEX_EFFORT_VALUE="${CODEX_EFFORT:-${CODEX_REASONING_EFFORT:-low}}"
CODEX_PROFILE=""
CODEX_SANDBOX="workspace-write"
ALLOW_EPIC=false
STRICT_READY=false
QUEUE_ORDER="${BW_CODEX_ORDER:-priority}"
USE_WORKTREE=false
WORKTREE_ROOT=""
BASE_REF=""
BRANCH_NAME=""
FRESH_WORKTREE=false
ALLOW_DIRTY=false
COMMIT_ALL_DIRTY=false
DIRTY_BASELINE_FILE=""
SYNC_AFTER=true
CLOSE_AFTER=true
VERIFY=true
FORMAT=true
FORMAT_CMD="${BW_CODEX_FORMAT_CMD:-mix format}"
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
    --effort)
      CODEX_EFFORT_VALUE="${2:-}"
      [[ -n "${CODEX_EFFORT_VALUE}" ]] || die "--effort requires a value"
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
    --order)
      QUEUE_ORDER="${2:-}"
      [[ -n "${QUEUE_ORDER}" ]] || die "--order requires a value"
      shift 2
      ;;
    --worktree)
      USE_WORKTREE=true
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
      FRESH_WORKTREE=false
      shift
      ;;
    --fresh-worktree)
      FRESH_WORKTREE=true
      shift
      ;;
    --allow-dirty)
      ALLOW_DIRTY=true
      shift
      ;;
    --commit-all-dirty)
      COMMIT_ALL_DIRTY=true
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
    --no-format)
      FORMAT=false
      shift
      ;;
    --format-cmd)
      FORMAT_CMD="${2:-}"
      [[ -n "${FORMAT_CMD}" ]] || die "--format-cmd requires a command"
      shift 2
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

validate_effort "${CODEX_EFFORT_VALUE}"
validate_order "${QUEUE_ORDER}"

if [[ "${COMMIT_ALL_DIRTY}" == "true" && "${ALLOW_DIRTY}" != "true" ]]; then
  die "--commit-all-dirty requires --allow-dirty"
fi

trap cleanup_baseline EXIT

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
ISSUE_STATUS="$(jq -r '.status' <<<"${ISSUE_JSON}")"
ISSUE_DESCRIPTION="$(jq -r '.description // ""' <<<"${ISSUE_JSON}")"

if [[ "${ISSUE_TYPE}" == "epic" && "${ALLOW_EPIC}" != "true" ]]; then
  die "${ISSUE_ID} is an epic. Pass --allow-epic if you really want to run it."
fi

if [[ "${ISSUE_STATUS}" == "closed" ]]; then
  log "${ISSUE_ID} is already closed; nothing to do."
  exit 0
fi

ISSUE_SLUG="$(printf '%s' "${ISSUE_TITLE}" | slugify)"
BRANCH_NAME="${BRANCH_NAME:-bw/${ISSUE_ID}-${ISSUE_SLUG}}"

if [[ "${USE_WORKTREE}" == "true" ]]; then
  WORKDIR="${WORKTREE_ROOT}/${ISSUE_ID}-${ISSUE_SLUG}"
else
  WORKDIR="${REPO_ROOT}"
  if [[ -n "${BRANCH_NAME}" && "${BRANCH_NAME}" != "bw/${ISSUE_ID}-${ISSUE_SLUG}" ]]; then
    die "--branch only applies with --worktree"
  fi
fi

export ISSUE_ID ISSUE_TITLE ISSUE_TYPE ISSUE_DESCRIPTION ISSUE_JSON WORKDIR REPO_ROOT

log "Selected ${ISSUE_ID}: ${ISSUE_TITLE}"
log "Workdir: ${WORKDIR}"

if [[ "${USE_WORKTREE}" == "true" ]]; then
  log "Branch: ${BRANCH_NAME}"
else
  log "Mode: current checkout"
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  log "Dry run enabled; no mutation will be performed."
fi

if [[ "${USE_WORKTREE}" == "true" ]]; then
  if [[ -e "${WORKDIR}" && "${FRESH_WORKTREE}" == "true" ]]; then
    die "worktree path already exists: ${WORKDIR}. Remove it or omit --fresh-worktree."
  fi

  if [[ ! -e "${WORKDIR}" ]]; then
    run mkdir -p "${WORKTREE_ROOT}"
    run git -C "${REPO_ROOT}" worktree add -b "${BRANCH_NAME}" "${WORKDIR}" "${BASE_REF}"
  else
    log "Reusing existing worktree: ${WORKDIR}"
  fi

  if [[ "${DRY_RUN}" == "true" && ! -d "${WORKDIR}/.git" ]]; then
    log "Worktree does not exist yet; skipping clean check because this is a dry run."
  else
    git_clean_or_allowed "${WORKDIR}"
  fi
else
  if [[ "${DRY_RUN}" == "true" && -n "$(git -C "${WORKDIR}" status --porcelain)" ]]; then
    log "Workdir is dirty; continuing because this is a dry run."
  else
    git_clean_or_allowed "${WORKDIR}"
  fi
fi

if [[ "${ALLOW_DIRTY}" == "true" && "${DRY_RUN}" != "true" ]]; then
  record_dirty_baseline "${WORKDIR}"
fi

EXISTING_COMMIT="$(issue_commit_sha "${WORKDIR}")"

if [[ -n "${EXISTING_COMMIT}" ]]; then
  if [[ -z "$(git -C "${WORKDIR}" status --porcelain)" ]]; then
    SHORT_COMMIT="$(git -C "${WORKDIR}" rev-parse --short "${EXISTING_COMMIT}")"
    log "Found existing commit for ${ISSUE_ID}: ${SHORT_COMMIT}; skipping Codex."
    finish_issue "${SHORT_COMMIT}"
    log "Done: ${ISSUE_ID}"
    exit 0
  fi
fi

run_hook "prepare" "${BW_CODEX_PREPARE_SCRIPT:-}" "${BW_CODEX_PREPARE_CMD:-}" "${WORKDIR}"

start_issue_if_needed

run_hook "pre-codex" "${BW_CODEX_PRE_CODEX_SCRIPT:-}" "${BW_CODEX_PRE_CODEX_CMD:-}" "${WORKDIR}"

if [[ "${DRY_RUN}" == "true" ]]; then
  PROMPT_FILE="$(prompt_path "${ISSUE_ID}")"
  log "Prompt would be written to ${PROMPT_FILE}"
else
  PROMPT_FILE="$(prompt_temp_path "${ISSUE_ID}")"
  write_prompt "${PROMPT_FILE}" "${CUSTOM_PROMPT_FILE}"
fi

run_codex "${PROMPT_FILE}" "${WORKDIR}"

if [[ "${DRY_RUN}" != "true" ]]; then
  rm -f "${PROMPT_FILE}"
fi

run_hook "review" "${BW_CODEX_REVIEW_SCRIPT:-}" "${BW_CODEX_REVIEW_CMD:-}" "${WORKDIR}"

if [[ "${FORMAT}" == "true" ]]; then
  run_shell_hook "format" "${FORMAT_CMD}" "${WORKDIR}"
fi

if [[ "${VERIFY}" == "true" ]]; then
  run_shell_hook "verify" "${VERIFY_CMD}" "${WORKDIR}"
fi

run_hook "pre-commit" "${BW_CODEX_PRE_COMMIT_SCRIPT:-}" "${BW_CODEX_PRE_COMMIT_CMD:-}" "${WORKDIR}"

if [[ "${DRY_RUN}" != "true" && -z "$(git -C "${WORKDIR}" status --porcelain)" ]]; then
  EXISTING_COMMIT="$(issue_commit_sha "${WORKDIR}")"

  if [[ -n "${EXISTING_COMMIT}" ]]; then
    SHORT_COMMIT="$(git -C "${WORKDIR}" rev-parse --short "${EXISTING_COMMIT}")"
    log "No working-tree changes, but ${ISSUE_ID} is already committed as ${SHORT_COMMIT}."
    finish_issue "${SHORT_COMMIT}"
    log "Done: ${ISSUE_ID}"
    exit 0
  fi

  die "Codex produced no working-tree changes."
fi

stage_changes "${WORKDIR}"
run git -C "${WORKDIR}" commit -m "${ISSUE_ID}: ${ISSUE_TITLE}" -m "Implemented from Beadwork issue ${ISSUE_ID}."

if [[ "${DRY_RUN}" == "true" ]]; then
  COMMIT_SHA="dry-run"
else
  COMMIT_SHA="$(git -C "${WORKDIR}" rev-parse --short HEAD)"
fi

run_hook "post-commit" "${BW_CODEX_POST_COMMIT_SCRIPT:-}" "${BW_CODEX_POST_COMMIT_CMD:-}" "${WORKDIR}"

finish_issue "${COMMIT_SHA}"

log "Done: ${ISSUE_ID}"
