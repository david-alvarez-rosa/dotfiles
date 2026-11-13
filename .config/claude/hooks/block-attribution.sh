#!/usr/bin/env sh

cmd=$(jq -r '.tool_input.command // ""')

echo "$cmd" | grep -q 'git .*commit' || exit 0

if echo "$cmd" | grep -qiE 'co-authored-by:.*(claude|anthropic)|generated with.*claude|claude-session:|claude\.ai/code/session'; then
    echo "Blocked: no AI attribution in commit messages." >&2
    exit 2
fi

if printf '%s' "$cmd" | perl -0777 -ne '
    s/"(?:\\.|[^"\\])*"|'"'"'[^'"'"']*'"'"'/ /gs;
    for (split /[;&|\n()]+/) {
        next unless s/^.*?(?:^|\s)git(?:\s+-\S+(?:\s+[^-\s]\S*)?)*\s+commit(?=\s|$)//;
        exit 0 if /\s(?:--no-verify|-[abd-ln-su-zABDEG-RT-Z]*n[a-zA-Z]*)(?=\s|=|$)/;
    }
    exit 1'; then
    echo "Blocked: commit hooks may not be bypassed." >&2
    exit 2
fi

exit 0
