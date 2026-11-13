# 課題A：最初にneg・bleのBasic列を観察して記録する．
# BEGIN/ENDの間だけ編集可．マーカーと範囲外の行は変更しない．
# 複数のRV32I基本命令と必要なラベルを使ってよい．
# 入力は3行：符号反転する整数，比較の左辺，比較の右辺．
# 出力は2行：符号反転結果，左辺<=右辺なら1，それ以外は0．
.data
NL: .string "\n"
.text
.globl main
main:
    li a7, 5
    ecall
    mv t0, a0
# BEGIN NEG
    neg t1, t0
# END NEG
    mv a0, t1
    li a7, 1
    ecall
    la a0, NL
    li a7, 4
    ecall

    li a7, 5
    ecall
    mv t0, a0
    li a7, 5
    ecall
    mv t1, a0
# BEGIN BLE
    ble t0, t1, taken
# END BLE
    li a0, 0
    j show_condition
taken:
    li a0, 1
show_condition:
    li a7, 1
    ecall
    la a0, NL
    li a7, 4
    ecall
    li a7, 10
    ecall
