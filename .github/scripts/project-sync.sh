#!/usr/bin/env bash
#
# project-sync.sh — drive the AnNIXion project board from CI.
# Field and option IDs are resolved by name at run time, so renaming or
# rebuilding the project does not silently break the automation.
#
#   sync   add an issue or PR to the board and set its fields
#   sweep  move every item in one status to another
#
# Needs GH_TOKEN with project read/write. See docs/dev.md.

# GraphQL queries below use $variables that must not be shell-expanded.
# shellcheck disable=SC2016

set -euo pipefail

PROJECT_OWNER="${PROJECT_OWNER:-Pyth3rEx}"
PROJECT_NUMBER="${PROJECT_NUMBER:-3}"

die() {
  echo "project-sync: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
usage: project-sync.sh sync  --content <node-id> [--status NAME] [--priority NAME]
                             [--size NAME] [--only-if-status NAME[,NAME...]]
                             [--only-if-empty]
       project-sync.sh sweep --from NAME --to NAME [--milestone TITLE]

  --content         node ID of the issue or pull request
  --status          status to set
  --priority/--size single-select values to set
  --only-if-status  only set the status when the item currently holds one of these
  --only-if-empty   only set priority/size when they are still empty
  --milestone       restrict a sweep to items on this milestone
  -h, --help        show this help
USAGE
}

# ── Project metadata ──────────────────────────────────────────────────────
# One query per run; every lookup below reads this.
load_project() {
  META="$(gh api graphql -f owner="$PROJECT_OWNER" -F number="$PROJECT_NUMBER" -f query='
    query($owner:String!, $number:Int!) {
      user(login: $owner) {
        projectV2(number: $number) {
          id
          fields(first: 50) {
            nodes {
              ... on ProjectV2SingleSelectField { id name options { id name } }
            }
          }
        }
      }
    }')"
  PROJECT_ID="$(jq -r '.data.user.projectV2.id // empty' <<< "$META")"
  [ -n "$PROJECT_ID" ] || die "project $PROJECT_OWNER/$PROJECT_NUMBER not found or token lacks project scope"
}

field_id() {
  jq -er --arg f "$1" \
    '.data.user.projectV2.fields.nodes[] | select(.name == $f) | .id' <<< "$META" \
    || die "no field named '$1' on the board"
}

option_id() {
  jq -er --arg f "$1" --arg o "$2" \
    '.data.user.projectV2.fields.nodes[] | select(.name == $f) | .options[] | select(.name == $o) | .id' <<< "$META" \
    || die "field '$1' has no option '$2'"
}

# ── Item helpers ──────────────────────────────────────────────────────────
# addProjectV2ItemById returns the existing item when it is already on the
# board, so this is safe to call on every event.
add_item() {
  gh api graphql -f project="$PROJECT_ID" -f content="$1" -f query='
    mutation($project:ID!, $content:ID!) {
      addProjectV2ItemById(input: {projectId: $project, contentId: $content}) {
        item { id }
      }
    }' --jq '.data.addProjectV2ItemById.item.id'
}

current_value() {
  gh api graphql -f item="$1" -f query='
    query($item:ID!) {
      node(id: $item) {
        ... on ProjectV2Item {
          fieldValues(first: 50) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field { ... on ProjectV2SingleSelectField { name } }
              }
            }
          }
        }
      }
    }' --jq ".data.node.fieldValues.nodes[] | select(.field.name == \"$2\") | .name"
}

set_select() {
  local item="$1" field="$2" value="$3" fid oid
  # Assigned first so an unknown field or option aborts here, under set -e,
  # rather than reaching the API as an empty argument.
  fid="$(field_id "$field")"
  oid="$(option_id "$field" "$value")"
  gh api graphql -f project="$PROJECT_ID" -f item="$item" \
    -f field="$fid" -f option="$oid" -f query='
    mutation($project:ID!, $item:ID!, $field:ID!, $option:String!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $project, itemId: $item, fieldId: $field,
        value: {singleSelectOptionId: $option}
      }) { projectV2Item { id } }
    }' > /dev/null
  echo "  $field → $value"
}

# Is the current status one of the comma-separated names the guard allows?
guard_allows() {
  local current="$1" allowed
  while IFS= read -r allowed; do
    [ "$current" = "$allowed" ] && return 0
  done <<< "${2//,/$'\n'}"
  return 1
}

# ── sync ──────────────────────────────────────────────────────────────────
cmd_sync() {
  local content="" status="" priority="" size="" guard="" only_if_empty=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --content)        content="$2"; shift 2 ;;
      --status)         status="$2"; shift 2 ;;
      --priority)       priority="$2"; shift 2 ;;
      --size)           size="$2"; shift 2 ;;
      --only-if-status) guard="$2"; shift 2 ;;
      --only-if-empty)  only_if_empty=1; shift ;;
      *) die "unknown argument: $1" ;;
    esac
  done
  [ -n "$content" ] || die "--content is required"

  load_project
  local item
  item="$(add_item "$content")"
  echo "item $item"

  if [ -n "$status" ]; then
    if [ -n "$guard" ] && ! guard_allows "$(current_value "$item" Status)" "$guard"; then
      echo "  Status left alone — not currently one of '$guard'"
    else
      set_select "$item" Status "$status"
    fi
  fi

  for pair in "Priority:$priority" "Size:$size"; do
    local field="${pair%%:*}" value="${pair#*:}"
    [ -n "$value" ] || continue
    if [ -n "$only_if_empty" ] && [ -n "$(current_value "$item" "$field")" ]; then
      echo "  $field already set — left alone"
      continue
    fi
    set_select "$item" "$field" "$value"
  done
}

# ── sweep ─────────────────────────────────────────────────────────────────
cmd_sweep() {
  local from="" to="" milestone=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --from)      from="$2"; shift 2 ;;
      --to)        to="$2"; shift 2 ;;
      --milestone) milestone="$2"; shift 2 ;;
      *) die "unknown argument: $1" ;;
    esac
  done
  [ -n "$from" ] && [ -n "$to" ] || die "--from and --to are required"

  # An empty --milestone would match only items that have none, which is never
  # what a caller resolving a release title meant.
  local scope=""
  if [ -n "$milestone" ]; then
    scope="| select(.content.milestone.title == \"$milestone\")"
  fi

  load_project
  local items
  items="$(gh api graphql --paginate -f project="$PROJECT_ID" -f query='
    query($project:ID!, $endCursor:String) {
      node(id: $project) {
        ... on ProjectV2 {
          items(first: 100, after: $endCursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              content {
                ... on Issue { milestone { title } }
                ... on PullRequest { milestone { title } }
              }
              fieldValues(first: 50) {
                nodes {
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    name
                    field { ... on ProjectV2SingleSelectField { name } }
                  }
                }
              }
            }
          }
        }
      }
    }' --jq ".data.node.items.nodes[]
              | select(any(.fieldValues.nodes[]?;
                  .field.name == \"Status\" and .name == \"$from\"))
              $scope
              | .id")"

  if [ -z "$items" ]; then
    echo "nothing in '$from'${milestone:+ on '$milestone'}"
    return 0
  fi

  while IFS= read -r item; do
    [ -n "$item" ] || continue
    echo "item $item"
    set_select "$item" Status "$to"
  done <<< "$items"
}

case "${1:-}" in
  sync)      shift; cmd_sync "$@" ;;
  sweep)     shift; cmd_sweep "$@" ;;
  -h|--help) usage ;;
  *)         usage; exit 64 ;;
esac
