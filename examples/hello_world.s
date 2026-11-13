# 例題1：Hello World．観察用．編集不要．
.text
.globl main
main:
    la a0, str
    li a7, 4
    ecall
    li a7, 10
    ecall

.data
str: .string "Hello World\n"
