#!/usr/bin/env bash
# 크기 경고 검사(D24). 알림용: 기준을 넘어도 종료 코드 0. --strict면 1.
# 기준은 임시값이다. 실제 코드를 보고 조정한다.
FILE_MAX=${FILE_MAX:-300}
FUNC_MAX=${FUNC_MAX:-40}
strict=0; [ "$1" = "--strict" ] && strict=1
warn=0
while IFS= read -r f; do
  n=$(wc -l < "$f")
  if [ "$n" -gt "$FILE_MAX" ]; then echo "WARN file $f: $n lines (> $FILE_MAX)"; warn=1; fi
  awk -v f="$f" -v max="$FUNC_MAX" '
    function flush() { if (name != "" && n > max) { printf "WARN func %s:%d %s: %d lines (> %d)\n", f, start, name, n, max; bad = 1 } name = "" }
    /^(static )?func / { flush(); name = $0; sub(/\(.*/, "", name); sub(/^(static )?func /, "", name); start = NR; n = 1; next }
    name != "" && /^[^ \t#]/ { flush() }
    name != "" { n++ }
    END { flush(); exit bad }
  ' "$f" || warn=1
done < <(git ls-files '*.gd')
[ "$warn" -eq 0 ] && echo "OK: no size warnings (file <= $FILE_MAX, func <= $FUNC_MAX)"
[ "$strict" -eq 1 ] && exit "$warn"
exit 0
