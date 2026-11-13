# 例題3のループ版．出力は123，空白・改行なし．観察用．編集不要．
.data
A: .word 1, 2, 3
.text
.globl main
main:
    la t0, A
    li t1, 3
loop:
    beq t1, zero, end
    lw a0, 0(t0)
    li a7, 1
    ecall
    addi t0, t0, 4
    addi t1, t1, -1
    j loop
end:
    li a7, 10
    ecall
