#!/bin/sh
# macOS / GNU/Linux用．POSIX sh，標準awk・sed等だけを使用する．
set -u
LC_ALL=C; export LC_ALL
cd "$(dirname "$0")/.." || exit 2
action=${1:-help}
child=
stop_child() {
    if [ -n "$child" ]; then
        kill -TERM "$child" 2>/dev/null || :
        sleep 0.2
        kill -KILL "$child" 2>/dev/null || :
        wait "$child" 2>/dev/null || :
        child=
    fi
}
trap 'stop_child' 0
trap 'exit 130' INT
trap 'exit 143' TERM HUP

case "$action" in
help)
    cat <<'HELP'
make check     Java / RARS / input / output / memory checks
make examples  Run the five example files (seven cases)
make test-a    Check editable regions, RV32I forms and Task A behavior
make test-b    Check Task B output AND post-run array memory
make test      Run BOTH A and B, even if A fails
make all       check + examples (succeeds with unfinished tasks)
make gui       Open RARS; select ONE source file and use 32-bit / Default
make clean     Remove this runner's build/run.* directories only
Edit tasks/pseudo_task.s and tasks/array_task.s inside BEGIN/END markers.
Distributed tasks are UNFINISHED: test-a, test-b and test must fail.
PASS is a check result, not a grade. See README for Japanese instructions.
HELP
    exit 0;;
clean)
    for dir in ./build/run.*; do
        if [ -d "$dir" ] && [ ! -L "$dir" ] && [ -f "$dir/.compsys-ex03-run" ]; then
            rm -rf "$dir" || exit 2
        fi
    done
    printf '%s\n' 'CLEAN: managed logs and temporary files removed; sources and tools kept'
    exit 0;;
check|examples|test-a|test-b|test|all|gui) ;;
*) printf 'Unknown target: %s\n' "$action" >&2; exit 2;;
esac

mkdir -p build || exit 2
work=$(mktemp -d './build/run.XXXXXX') || exit 2
: > "$work/.compsys-ex03-run"
printf 'Logs: %s\n' "$work"

# CRLFのみ正規化する．改行なしの出力と末尾の裸CRは保持する．
normalise() {
    if [ "$(tail -c 1 "$1")" = "$(printf '\r')" ]; then cat "$1"
    else sed "s/$(printf '\r')$//" "$1"; fi
}

# 監視用の常駐子プロセスは作らず，親がJava PIDを監視・waitする．
bounded() {
    dest=$1; input=$2; shift 2
    mkdir -p "$dest" || return 2
    date -u '+%Y-%m-%dT%H:%M:%SZ' > "$dest/start.txt"
    printf '%s\n' "$@" > "$dest/argv.txt"
    (ulimit -f 2048; exec "$@") < "$input" > "$dest/stdout.txt" 2> "$dest/stderr.txt" &
    child=$!
    printf '%s\n' "$child" > "$dest/pid.txt"
    start=$(date +%s); reason=
    while kill -0 "$child" 2>/dev/null; do
        now=$(date +%s)
        if [ "$((now-start))" -ge 20 ]; then reason='wall-time limit (20 seconds)'; break; fi
        size=$(wc -c < "$dest/stdout.txt"); errsize=$(wc -c < "$dest/stderr.txt")
        if [ "$size" -gt 1048576 ] || [ "$errsize" -gt 1048576 ]; then reason='output size limit'; break; fi
        sleep 0.1
    done
    if [ -n "$reason" ]; then
        stop_child; rc=124
        printf '%s\n' "$reason" > "$dest/limit.txt"
    else
        wait "$child"; rc=$?; child=
    fi
    printf '%s\n' "$rc" > "$dest/exit.txt"
    date -u '+%Y-%m-%dT%H:%M:%SZ' > "$dest/end.txt"
    return "$rc"
}

absolute_file() {
    ap=$1
    case "$ap" in */*) ;; *) ap=$(command -v "$ap" 2>/dev/null) || return 1;; esac
    [ -f "$ap" ] || return 1
    (cd "$(dirname "$ap")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$ap")")
}

environment() {
    if [ -n "${JAVA:-}" ]; then java_source=JAVA; candidate=$JAVA
    elif [ -n "${JAVA_HOME:-}" ]; then java_source=JAVA_HOME; candidate=$JAVA_HOME/bin/java
    else java_source=PATH; candidate=java; fi
    java=$(absolute_file "$candidate") || {
        printf '[ENV-JAVA] FAIL: Java not found via %s: %s\n' "$java_source" "$candidate" >&2; return 2;
    }
    [ -x "$java" ] || { printf '[ENV-JAVA] FAIL: not executable: %s\n' "$java" >&2; return 2; }
    printf 'Java source: %s\nJava executable: %s\n' "$java_source" "$java"
    if ! bounded "$work/java-version" /dev/null "$java" -version; then
        printf '[ENV-JAVA] FAIL: cannot run Java (a launcher stub is not enough)\n' >&2
        cat "$work/java-version/stderr.txt" >&2; return 2
    fi
    cat "$work/java-version/stdout.txt" "$work/java-version/stderr.txt" > "$work/java-version/banner.txt"
    cat "$work/java-version/banner.txt"
    major=$(awk -F '"' '/version "/ {split($2,a,"."); if(a[1]==1) print a[2]; else print a[1]; exit}' "$work/java-version/banner.txt")
    case "$major" in ''|*[!0-9]*) printf '[ENV-JAVA] FAIL: version not recognised\n' >&2; return 2;; esac
    [ "$major" -ge 8 ] || { printf '[ENV-JAVA] FAIL: Java 8 or later required\n' >&2; return 2; }
    if [ -n "${RARS_JAR:-}" ]; then jar_source=RARS_JAR; candidate=$RARS_JAR
    elif [ -n "${COMPSYS_TOOLS:-}" ]; then jar_source=COMPSYS_TOOLS; candidate=$COMPSYS_TOOLS/rars1_6.jar
    else jar_source=HOME; candidate=${HOME:?HOME is required}/compsys-tools/rars1_6.jar; fi
    jar=$(absolute_file "$candidate") || {
        printf '[ENV-RARS] FAIL: JAR not found via %s: %s\nExpected default: %s/compsys-tools/rars1_6.jar\n' "$jar_source" "$candidate" "${HOME:-~}" >&2; return 2;
    }
    printf 'RARS source: %s\nRARS JAR: %s\n' "$jar_source" "$jar"
    if command -v shasum >/dev/null 2>&1; then actual=$(shasum -a 256 "$jar")
    elif command -v sha256sum >/dev/null 2>&1; then actual=$(sha256sum "$jar")
    else printf '[ENV-SHA] FAIL: shasum or sha256sum is required\n' >&2; return 2; fi
    actual=${actual%% *}; expected=$(cat tools/rars.sha256)
    [ "$actual" = "$expected" ] || { printf '[ENV-SHA] FAIL: expected %s; actual %s\n' "$expected" "$actual" >&2; return 2; }
    printf 'RARS v1.6 SHA-256: %s\n' "$actual"
    if ! bounded "$work/rars-version" /dev/null "$java" -Dfile.encoding=UTF-8 -jar "$jar" h ||
       ! grep '^RARS 1\.6  ' "$work/rars-version/stdout.txt" >/dev/null; then
        printf '[ENV-RARS] FAIL: cannot confirm the RARS 1.6 banner\n' >&2; return 2
    fi
    head -n 1 "$work/rars-version/stdout.txt"
    return 0
}

# 呼出しごとの独立した出力先を用い，dumpを再利用しない．
rars() {
    case_dir=$1; in_file=$2; phase=$3; shift 3
    if ! bounded "$case_dir" "$in_file" "$java" -Dfile.encoding=UTF-8 -Xmx128m -jar "$jar" nc me ae11 se12 mc Default sm 100000 "$@"; then
        printf '[RUN] FAIL: %s (exit %s)\n' "$case_dir" "$(cat "$case_dir/exit.txt")" >&2
        cat "$case_dir/stderr.txt" >&2; return 1
    fi
    normalise "$case_dir/stdout.txt" > "$case_dir/stdout.lf"
    normalise "$case_dir/stderr.txt" > "$case_dir/stderr.lf"
    if grep -E '(^Error|^Warning|Exception|terminated due|maximum step|Invalid|nothing to dump|Error while)' "$case_dir/stderr.lf" >/dev/null; then
        printf '[RUN] FAIL: RARS diagnostic in %s\n' "$case_dir" >&2
        cat "$case_dir/stderr.txt" >&2; return 1
    fi
    if [ "$phase" = run ] && ! grep -Fx 'Program terminated by calling exit' "$case_dir/stderr.lf" >/dev/null; then
        printf '[RUN] FAIL: normal Exit was not observed in %s\n' "$case_dir" >&2
        cat "$case_dir/stderr.txt" >&2; return 1
    fi
    return 0
}

memory() {
    dump=$1; words=$2; target=$3
    [ -f "$dump" ] || { printf '[MEMORY] FAIL: dump missing: %s\n' "$dump" >&2; return 1; }
    normalise "$dump" > "$dump.lf"
    awk -v count="$words" '
      length($0)!=8 || $0 !~ /^[0-9a-fA-F]+$/ {bad=1}
      {v=0;for(i=1;i<=length($0);i++)v=v*16+index("0123456789abcdef",tolower(substr($0,i,1)))-1;
       if(v>=2147483648)v-=4294967296;printf "%.0f\n",v}
      END {if(NR!=count || bad)exit 1}
    ' "$dump.lf" > "$target" || { printf '[MEMORY] FAIL: malformed dump or wrong word count\n' >&2; return 1; }
}

compare_output() {
    output_id=$1; expected_file=$2; actual_file=$3
    if cmp -s "$expected_file" "$actual_file"; then
        printf '[%s] PASS stdout (%s bytes): ' "$output_id" "$(wc -c < "$actual_file" | tr -d ' ')"
        cat "$actual_file"; printf '\n'; return 0
    fi
    printf '[%s] FAIL stdout; expected bytes: ' "$output_id"
    od -An -tx1 "$expected_file"
    printf 'actual bytes: '; od -An -tx1 "$actual_file"
    return 1
}

check() {
    printf '42' > "$work/check.expected"
    printf '41\n' > "$work/check.input"
    rars "$work/check" "$work/check.input" run dump 0x10010000-0x10010004 HexText "$work/check.hex" tools/check.s || return 1
    compare_output CHECK-IO "$work/check.expected" "$work/check/stdout.lf" || return 1
    memory "$work/check.hex" 1 "$work/check.dec" || return 1
    [ "$(cat "$work/check.dec")" = 42 ] || { printf '[CHECK-MEMORY] FAIL\n'; return 1; }
    printf '[CHECK-MEMORY] PASS post-run 0x10010000 = 42 (initial value 0)\n'
}

cases() {
    group=$1; failed=0
    while IFS="$(printf '\t')" read -r g id source input expected; do
        [ "$g" = "$group" ] || continue
        prefix=$work/$id
        if [ "$input" = - ]; then : > "$prefix.input"; else printf '%b' "$input" > "$prefix.input"; fi
        printf '%b' "$expected" > "$prefix.expected"
        if rars "$prefix" "$prefix.input" run "$source"; then
            compare_output "$id" "$prefix.expected" "$prefix/stdout.lf" || failed=1
        else printf '[%s] FAIL execution\n' "$id"; failed=1; fi
    done < tests/cases.tsv
    return "$failed"
}

task_a() {
    awk -v kind=A -v out="$work/a-np.s" -f tools/source.awk tests/pseudo.original.s tasks/pseudo_task.s
    scope_rc=$?
    [ "$scope_rc" -ne 2 ] || return 1
    instruction_rc=$scope_rc
    if [ "$instruction_rc" -eq 0 ]; then
        if rars "$work/a-np" /dev/null assemble a np "$work/a-np.s"; then
            printf '[A-RV32I] PASS basic instruction forms (np on extracted regions)\n'
        else printf '[A-RV32I] FAIL pseudo / invalid operand form\n'; instruction_rc=1; fi
    fi
    cases A; behavior_rc=$?
    if [ "$instruction_rc" -eq 0 ] && [ "$behavior_rc" -eq 0 ]; then printf '[A] PASS\n'; return 0; fi
    printf '[A] FAIL / UNFINISHED (see separate scope, instruction and behavior results)\n'
    return 1
}

task_b() {
    awk -v kind=B -f tools/source.awk tests/array.original.s tasks/array_task.s || return 1
    b_failed=0
    while IFS="$(printf '\t')" read -r g id source input ignored; do
        [ "$g" = B ] || continue
        prefix=$work/$id
        # 差替えは一致する専用データ行だけ．他の即値や定数は触らない．
        awk -v values="$input" '{sub(/\r$/, "");if($0=="A: .word 7, -2, 5, -8, 3, -1") {print "A: .word " values;n++} else print} END{if(n!=1)exit 1}' "$source" > "$prefix.s" || return 1
        printf '%s\n' "$input" | awk -F, -v out="$prefix.expected" -v mem="$prefix.expected-mem" -v initial="$prefix.initial" '
            {s=0;for(i=1;i<=NF;i++){print $i > initial;v=($i<0?-$i:$i);s+=v;print v > mem;printf "%s%d",(i==1?"":" "),v > out}printf "\n%d\n",s > out}
        ' || return 2
        # 保護された.data先頭のAがDefaultの6ワードに一致することを検査．
        if ! rars "$prefix-assemble" /dev/null assemble a dump 0x10010000-0x10010018 HexText "$prefix.initial.hex" "$prefix.s" ||
           ! memory "$prefix.initial.hex" 6 "$prefix.initial.dec" || ! cmp -s "$prefix.initial" "$prefix.initial.dec"; then
            printf '[%s-LAYOUT] FAIL initial A layout\n' "$id"; b_failed=1; continue
        fi
        printf '[%s-LAYOUT] PASS A = 0x10010000, six words\n' "$id"
        if ! rars "$prefix-run" /dev/null run dump 0x10010000-0x10010018 HexText "$prefix.after.hex" "$prefix.s"; then
            printf '[%s] FAIL execution\n' "$id"; b_failed=1; continue
        fi
        compare_output "$id-OUTPUT" "$prefix.expected" "$prefix-run/stdout.lf" || b_failed=1
        if memory "$prefix.after.hex" 6 "$prefix.after.dec" && cmp -s "$prefix.expected-mem" "$prefix.after.dec"; then
            printf '[%s-MEMORY] PASS ' "$id"; paste -sd ' ' "$prefix.after.dec"
        else
            printf '[%s-MEMORY] FAIL expected: ' "$id"; paste -sd ' ' "$prefix.expected-mem"
            if [ -f "$prefix.after.dec" ]; then printf 'actual: '; paste -sd ' ' "$prefix.after.dec"; fi
            b_failed=1
        fi
    done < tests/cases.tsv
    if [ "$b_failed" -eq 0 ]; then printf '[B] PASS\n'; else printf '[B] FAIL / UNFINISHED\n'; fi
    return "$b_failed"
}

environment || exit 2
case "$action" in
check) check; result=$?;;
examples) cases EX; result=$?;;
all) check && cases EX; result=$?;;
test-a) task_a; result=$?;;
test-b) task_b; result=$?;;
test) task_a; a_result=$?; task_b; b_result=$?; result=0
    [ "$a_result" -eq 0 ] && [ "$b_result" -eq 0 ] || result=1
    printf '[TEST] A=%s B=%s (0=PASS, 1=FAIL/UNFINISHED)\n' "$a_result" "$b_result";;
gui) exec "$java" -Dfile.encoding=UTF-8 -jar "$jar";;
esac
printf 'Runner exit: %s; logs: %s\n' "$result" "$work"
exit "$result"
