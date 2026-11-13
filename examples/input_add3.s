# 例題2の入力への拡張．観察用．編集不要．
.data
AQ: .string "A?:"
NL: .string "\n"
.text
.globl main
main:
    la a0, AQ
    li a7, 4
    ecall
    li a7, 5
    ecall
    addi a0, a0, 3
    li a7, 1
    ecall
    la a0, NL
    li a7, 4
    ecall
    li a7, 10
    ecall
