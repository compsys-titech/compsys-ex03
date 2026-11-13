# 例題2：固定値1＋2．出力は3，改行なし．観察用．編集不要．
.text
.globl main
main:
    li t0, 1
    li t1, 2
    add t0, t0, t1
    mv a0, t0
    li a7, 1
    ecall
    li a7, 10
    ecall
