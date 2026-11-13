# 配布原本との範囲比較と課題Aの命令検査．POSIX awkで動作する．
# kind=A/B，out=課題Aのnp検査用ファイル．学生は編集しない．
BEGIN {
    count = kind == "A" ? 4 : 2
    if (kind == "A") {
        marker[1]="# BEGIN NEG"; marker[2]="# END NEG"
        marker[3]="# BEGIN BLE"; marker[4]="# END BLE"
    } else { marker[1]="# BEGIN TODO"; marker[2]="# END TODO" }
    split("lui auipc jal jalr beq bne blt bge bltu bgeu lb lh lw lbu lhu sb sh sw addi slti sltiu xori ori andi slli srli srai add sub sll slt sltu xor srl sra or and fence ecall ebreak", ops, " ")
    for (i in ops) allowed[ops[i]]=1
}
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function strip_labels(s,    n) {
    labels=""
    while (match(s, /^[ \t]*[A-Za-z_.$][A-Za-z0-9_.$]*[ \t]*:/)) {
        labels=labels substr(s,1,RLENGTH) "\n"
        s=substr(s,RLENGTH+1)
    }
    return trim(s)
}
FNR == 1 { file++; stage=0 }
{
    line=$0; sub(/\r$/, "", line)
    ismarker=0
    for (i=1; i<=count; i++) if (line==marker[i]) {
        ismarker=1
        if (i!=stage+1) badscope=1
        stage=i; seen[file]++
    }
    if (ismarker || stage%2==0) outside[file]=outside[file] line "\n"
    if (file==2 && !ismarker) {
        code=line; sub(/#.*/, "", code); code=strip_labels(code)
        if (stage%2==1) {
            if (length(code)) bodylines++
            if (kind=="A" && length(code)) {
                split(code,words,/[ \t,]+/)
                if (!(words[1] in allowed)) {
                    print "[A-RV32I] FAIL line " FNR ": " words[1] " is not an RV32I basic instruction"
                    if (words[1]=="neg" || words[1]=="ble") unconverted=1
                    badop=1
                }
            }
            np=np line "\n"
        } else {
            # 指定範囲外の命令だけを基本nopにする．全ラベル・データは保持．
            # npはこの検査専用コピーに適用し，配布版全体には適用しない．
            np=np labels
            if (code ~ /^\./) np=np code "\n"
            else if (length(code)) np=np "addi zero, zero, 0\n"
        }
    }
}
END {
    if (file!=2 || seen[1]!=count || seen[2]!=count || badscope || outside[1]!=outside[2]) {
        print "[" kind "-SCOPE] FAIL: markers or lines outside the editable regions differ"
        exit 2
    }
    print "[" kind "-SCOPE] PASS: markers and protected lines match"
    if (kind=="A") {
        printf "%s",np > out; close(out)
        if (unconverted) print "[A-STATE] UNFINISHED: neg / ble has not been replaced"
        if (badop) exit 1
    } else if (!bodylines) print "[B-STATE] UNFINISHED: TODO has no executable code"
}
