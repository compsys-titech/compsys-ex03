# 環境確認用．入力，整数表示，同じ実行後のメモリ取得を検査する．編集不要．
.data
Cell: .word 0
.text
.globl main
main:
    li a7, 5
    ecall
    addi a0, a0, 1
    la t0, Cell
    sw a0, 0(t0)
    li a7, 1
    ecall
    li a7, 10
    ecall
