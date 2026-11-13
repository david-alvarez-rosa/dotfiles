#!/usr/bin/env sh

cmd=$(jq -r '.tool_input.command // ""')

echo "$cmd" | grep -q 'git .*commit' || exit 0

if echo "$cmd" | grep -qiE 'co-authored-by:.*(claude|anthropic)|generated with.*claude|claude-session:|claude\.ai/code/session'; then
    echo "Blocked: no AI attribution in commit messages." >&2
    exit 2
fi

if echo "$cmd" | grep -qE 'git[^;&|]* commit[^;&|]*( --no-verify| -[a-zA-Z]*n[a-zA-Z]*\b)'; then
    echo "Blocked: commit hooks may not be bypassed." >&2
    exit 2
fi

exit 0
