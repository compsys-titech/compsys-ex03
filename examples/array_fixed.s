# 例題3の固定オフセット比較版．出力は123，空白・改行なし．編集不要．
.data
A: .word 1, 2, 3
.text
.globl main
main:
    la t0, A
    lw a0, 0(t0)
    li a7, 1
    ecall
    lw a0, 4(t0)
    li a7, 1
    ecall
    lw a0, 8(t0)
    li a7, 1
    ecall
    li a7, 10
    ecall
