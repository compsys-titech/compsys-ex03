# 2026年度「計算機システム（演習）」第3回

**目次**

- [1．この回で学ぶこと](#1この回で学ぶこと)
- [2．必要なツールと確認環境](#2必要なツールと確認環境)
- [3．教材の取得・更新](#3教材の取得更新)
- [4．ファイル構成と編集範囲](#4ファイル構成と編集範囲)
- [5．JavaとRARSの準備](#5javaとrarsの準備)
- [6．環境確認と例題](#6環境確認と例題)
- [7．RARSの画面操作](#7rarsの画面操作)
- [8．課題Aの進め方](#8課題aの進め方)
- [9．課題Bの進め方](#9課題bの進め方)
- [10．コマンドとテスト結果](#10コマンドとテスト結果)
- [11．レポート・提出・評価](#11レポート提出評価)
- [12．トラブルシューティング](#12トラブルシューティング)
- [13．出典](#13出典)

## 1．この回で学ぶこと

東京科学大学，数理・計算科学系の学部2年生向け教材である．RARSでRISC-Vアセンブリを直接書き，命令，レジスタ，メモリ，入出力を対応付ける．整数演算，分岐とループ，`lw`／`sw`，疑似命令と基本命令を扱う．

例題は授業中の観察用であり，採点対象外である．課題Aでは疑似命令を置き換え，課題Bでは配列の変換を実装する．**配布直後の課題は未完成であり，課題テストが不合格になるのが正常である．**

## 2．必要なツールと確認環境

- Git，GNU Make，Java 8以上，テキストエディタ．
- **RARS v1.6**の公式`rars1_6.jar`．32ビットモード，Memory Configurationは**Default**を使う．
- 学習対象はRV32Iの整数命令と授業で扱う疑似命令．RARSのEnvironment Callの番号を使う．
- macOS／GNU/Linuxは標準シェルと標準コマンド，WindowsはWindows PowerShell 5.1とGNU Makeを使う．

GCC，QEMU，GDB，ELF生成，Python，Node.js，Docker，WSL，`javac`は必要ない．管理者権限や恒久的なPATH変更を前提にしない．通常のmake実行ではダウンロードやネット接続を行わない．

| 実際に確認した環境 | 使用した版 | 確認範囲 |
| --- | --- | --- |
| macOS 27.2.1／Apple Silicon（arm64） | Java 1.8.0_511，GNU Make 3.81，RARS 1.6 | CLIとRARS GUI |
| Debian GNU/Linux 13.6（trixie）／x86_64 | OpenJDK 21.0.12.1，GNU Make 4.4.1，RARS 1.6 | CLI．GUIは未確認 |

CLIではMakefile，例題，未完成課題の判定，隔離した正解版，誤実装・異常系，日本語・空白パス，読取り専用HOME，実行後メモリdump，タイムアウトと後始末を確認した．macOSではRARS GUIのHello World実行，Basic列，Data Segmentも確認済みである．

Windows x64と西8計算機実習室GNU/LinuxはTAによる確認を予定している．

## 3．教材の取得・更新

初めて取得するときは，書込み可能なフォルダーで実行する．

```sh
git clone https://github.com/compsys-titech/compsys-ex03.git
cd compsys-ex03
```

取得済みの場合は，編集済みの課題ファイルを保持したうえで，教材のルートで更新する．必要に応じて自分の編集をリポジトリ外にもコピーして保管する．

```sh
git status --short
git pull --ff-only
```

競合やエラーが出た場合は，編集を消さず教員・TAへ相談する．課題ファイルを配布版で上書きしない．元の公開リポジトリへのpushやPull Requestは不要である．以降のmakeコマンドは，`Makefile`がある教材のルートで実行する．

## 4．ファイル構成と編集範囲

```text
compsys-ex03/
├── README.md
├── AGENTS.md
├── Makefile
├── .gitignore
├── .gitattributes
├── examples/
│   ├── hello_world.s
│   ├── arithmetic.s
│   ├── input_add3.s
│   ├── array_fixed.s
│   └── array_walk.s
├── tasks/
│   ├── pseudo_task.s
│   └── array_task.s
├── tools/
│   ├── run.sh
│   ├── run.ps1
│   ├── source.awk
│   ├── check.s
│   └── rars.sha256
├── tests/
│   ├── cases.tsv
│   ├── pseudo.original.s
│   └── array.original.s
├── report/
│   ├── README.md
│   └── ex03-report-template.docx
└── build/
    └── .gitkeep
```

| ファイル | 役割 | 編集してよい範囲 |
| --- | --- | --- |
| [examples/hello_world.s](examples/hello_world.s) | 例題1：文字列表示 | 観察用．編集不要 |
| [examples/arithmetic.s](examples/arithmetic.s)，[input_add3.s](examples/input_add3.s) | 例題2：固定値の計算と整数入力への拡張 | 観察用．編集不要 |
| [examples/array_fixed.s](examples/array_fixed.s)，[array_walk.s](examples/array_walk.s) | 例題3：固定オフセットとの比較，ループによる配列走査 | 観察用．編集不要 |
| [tasks/pseudo_task.s](tasks/pseudo_task.s) | 課題A：neg・bleの観察と置換 | `BEGIN NEG`～`END NEG`，`BEGIN BLE`～`END BLE`の内側だけ |
| [tasks/array_task.s](tasks/array_task.s) | 課題B：配列の変換・書戻し・合計・表示 | `BEGIN TODO`～`END TODO`の内側だけ |
| [Makefile](Makefile)，[tools/](tools/)，[tests/](tests/) | 実行・検査と配布原本 | 編集しない |
| [report/README.md](report/README.md)，[Word雛形](report/ex03-report-template.docx) | 記入ガイドとレポート雛形 | 雛形をリポジトリ外へコピーして記入 |
| `build/` | 実測ログ，一時ソース，メモリdump | 自動生成．レポート等の保管には使わない |
| [AGENTS.md](AGENTS.md)，[.gitignore](.gitignore)，[.gitattributes](.gitattributes) | 保守・Gitの管理設定 | 編集しない |

マーカーの行そのものと，その外側は変更しない．文字コードはUTF-8とする．課題のLF／CRLFの違いだけでは範囲検査を不合格にしない．レポートは[正式な記入ガイド](report/README.md)に従い，Word雛形をリポジトリ外へコピーして作成する．

## 5．JavaとRARSの準備

### Javaの確認

```sh
java -version
```

実際に版が表示されることを確認する．`1.8.0_...`はJava 8を表す．インストールを案内する起動用スタブだけでは準備完了にならない．既存のJava 8以上が使えれば再利用する．

Javaがない場合は，OS・CPUに合う公式配布を使用する．例えば[Eclipse Temurinの公式アーカイブ導入手順](https://adoptium.net/installation/)からJRE（実行環境）のZIP／tar.gzを選び，ホームの`compsys-tools`内の別フォルダーへ展開できる．JDKも使えるが，ソースビルドは不要である．Windowsはx64，Apple Siliconはaarch64，macOS Intelはx64など，自分のCPUに合うものを選ぶ．GNU/Linuxも`uname -m`で確認する．

`bin/java`（Windowsは`bin\java.exe`）を含むフォルダーを，現在の端末だけで`JAVA_HOME`へ指定する．macOSのアーカイブでは`Contents/Home`が該当する場合がある．次のパスは自分の配置先へ置き換える．

```sh
export JAVA_HOME="$HOME/compsys-tools/展開したJavaのフォルダー"
```

```powershell
$env:JAVA_HOME = "$HOME\compsys-tools\展開したJavaのフォルダー"
```

学校の管理PCでJavaやGit・Makeが使えない場合は教員・TAへ相談する．システム設定，セキュリティ設定，恒久的PATHを変更する作業は本教材の手順に含めない．

### RARSの配置

[公式v1.6 Release](https://github.com/TheThirdOne/rars/releases/tag/v1.6)のAssetsから，**[rars1_6.jar](https://github.com/TheThirdOne/rars/releases/download/v1.6/rars1_6.jar)**を取得する．continuous buildや再配布版を使わない．ブラウザーで保存し，ホーム直下の`compsys-tools`へ置く．

```text
ホーム/
└── compsys-tools/
    └── rars1_6.jar
```

Windowsではエクスプローラーで`%USERPROFILE%`，macOSではFinderの「移動」→「ホーム」，GNU/Linuxではファイルマネージャーのホームから作成できる．JARやJava本体を教材リポジトリ内へ置かない．既存の同名ファイルを確認せず上書きしない．

教材が使用するJARは1,860,244バイトで，SHA-256は次の値である．2026年11月13日に上記公式URLから取得して計算した**同一性確認用の固定値**であり，公式チェックサムではない．取得時のReleaseにはチェックサムファイルおよびasset digestがなかった．`make check`がこの値との一致を確認する．

```text
780f730eb457b1ba609e968accc2c8b77d8f92c3d9dbf30cc7fdb3cfb14e8c24
```

### Makeの準備と探索順

macOS／GNU/LinuxはPCに用意されたGNU Makeを使う．Windowsは第1・2回と同じ[xPack Windows Build Tools 4.4.1-3](https://github.com/xpack-dev-tools/windows-build-tools-xpack/releases/tag/v4.4.1-3)を使える．展開先が標準配置なら，教材ルートでPowerShellを開き，現在のウィンドウだけに別名を設定する．

```powershell
Set-Alias -Name make -Value "$HOME\compsys-tools\xpack-windows-build-tools-4.4.1-3\bin\make.exe"
```

RARSの探索順は`RARS_JAR`，`COMPSYS_TOOLS/rars1_6.jar`，ホームの`compsys-tools/rars1_6.jar`．Javaの探索順は`JAVA`（実行ファイル），`JAVA_HOME/bin/java`，PATHである．明示指定が不正な場合，別の場所へ黙って切り替えない．標準配置ならRARS用の設定は不要である．

別配置を使う場合の例（現在の端末だけ有効）：

```sh
export COMPSYS_TOOLS="/path/with spaces/compsys-tools"
export JAVA="/path/with spaces/java/bin/java"
```

```powershell
$env:COMPSYS_TOOLS = 'D:\path with spaces\compsys-tools'
$env:JAVA = 'D:\path with spaces\java\bin\java.exe'
```

JARを直接指定する場合は`RARS_JAR`へファイルのパスを設定する．不要になった場合は`compsys-tools`内の該当JAR／Javaのフォルダーをごみ箱へ移せる．

## 6．環境確認と例題

```sh
make check
make examples
```

`check`は採用したJava・RARSの探索元，絶対パス，版，SHAを表示する．小さな確認用プログラムが入力41から42を計算し，その出力と実行後のメモリを検査する．課題が未完成でも成功する．

`examples`は各ファイルを個別にassemble・runする．入力例には標準入力も自動で供給する．

| 対応 | ファイル | プログラム自身の出力 |
| --- | --- | --- |
| 例題1 | `hello_world.s` | `Hello World`＋改行 |
| 例題2 | `arithmetic.s` | `3`（改行なし） |
| 例題2の拡張 | `input_add3.s` | 入力5：`A?:8`＋改行，入力−5：`A?:-2`＋改行，入力0：`A?:3`＋改行 |
| 例題3の比較版 | `array_fixed.s` | `123`（空白・改行なし） |
| 例題3のループ版 | `array_walk.s` | `123`（空白・改行なし） |

5ファイルは3つの例題と拡張・比較版である．CLIでは入力のエコーをプログラム出力へ加えない．GUIのRun I/Oには入力した文字やRARS自身のメッセージも見えるため，プログラムが表示した文字と区別する．

## 7．RARSの画面操作

```sh
make gui
```

1. Settingsで64ビットモードを使用せず，Memory Configurationを**Default**にする．「Assemble all files in directory」の設定はオフにし，今回実行するソース1個だけを開く．
2. File → Openで，例として`examples/hello_world.s`を開く．他の例題・課題を同時にassembleしない．
3. Run → Assembleを選び，エラーがないことを確認する．
4. Execute画面のText Segmentで，Sourceと**Basic**列を対応付ける．Basic列には疑似命令の展開後の命令が出る．ABI名と`x`番号，ラベルと数値表示の違いに注意する．
5. Run → Go（実行ボタン）で実行する．Run I/Oで結果を確認する．入力例では整数を入力してEnterを押す．
6. Run → Stepで基本命令を1命令ずつ実行できる．レジスタとData Segmentを観察する．再実行にはReset，ソースを変更した後は保存・再Assembleを行う．

課題Bの配列はData Segmentでラベル`A`に対応する先頭を探し，**値の16進表示をオフにして10進数で**6ワードを読む．アドレス表示と値表示を混同しない．本教材のDefault配置ではAは`0x10010000`から4バイトずつ並ぶ．Run後，**Reset・再Assembleの前**に記録する．確認のためにメモリのセルを直接書き換えない．

## 8．課題Aの進め方

1. 編集前の`tasks/pseudo_task.s`をassembleし，`neg`と`ble`に対応するBasic列を記録する．
2. 2つの指定範囲だけを，同じ働きのRV32I基本命令へ置き換える．複数命令や必要なラベルを使ってよい．1命令や最短命令数は要求しない．指定範囲外の`li`，`la`等はそのまま残す．
3. 保存して再Assemble・Runする．入力は「符号反転する整数」「比較の左辺」「比較の右辺」の3行である．出力は符号反転結果と，比較が成立すれば1，それ以外は0の2行である．
4. 次を実行し，表示された識別名と実際の結果を記録する．

```sh
make test-a
```

検査は`A-SCOPE`（範囲・マーカー），`A-RV32I`（基本命令とオペランド形式），動作ケースに分かれる．コメントに`neg`と書いたことだけでは不合格にしない．他の疑似命令，拡張命令，マクロ・include・機械語の埋込みで基本命令の指定を回避しない．Basic列との文字列完全一致や特定の補助レジスタは要求しない．

動作の識別名は`A-POS-LT`，`A-NEG-GT`，`A-ZERO-EQ`，`A-MIX-LT`，`A-MIX-GT`，`A-NEG-LT`，`A-NEG-PAIR-GT`，`A-ZERO-PAIR-EQ`，`A-ZERO-LEFT-GT`である．正・負・0の符号反転と，符号付き比較の小・等・大，正負混合・負数同士を確認する．

配布版は動作ケースに合格しても`A-STATE UNFINISHED`となる．命令を置換した後，編集前のBasic列と自分の命令について，命令・オペランド・分岐条件の対応を説明する．

## 9．課題Bの進め方

`tasks/array_task.s`のTODO範囲へ，自分のプログラムを記述する．配布版はassembleできるが，まだ何も表示せず終了する．

- `A: .word 7, -2, 5, -8, 3, -1`の6要素をループで読む．
- 負数を絶対値へ変換し，0と正数は保ち，同じAの要素へ書き戻す．
- 変換後の要素を合計し，要素と合計をEnvironment Callで表示する．
- ループ，`lw`，`sw`，条件分岐，算術命令を使う．処理を6回複製せず，要素の個別アドレスをハードコードしない．関数呼出し，スタック，ヒープを使わない．
- 授業の疑似命令を使ってよい．レジスタ割当やループの数は自分で決める．初期値，要素数6，要素幅4，サービス番号，空白・改行などの定数は使える．
- 計算結果を即値，文字列，計算済み別配列で代用しない．

スライド指定配列の出力形式：

```text
7 2 5 8 3 1
26
```

1行目は半角空白1個で区切り，行頭・行末に空白を付けない．2行目は合計だけとし，両行末に改行する．余分な説明文を出力しない．

```sh
make test-b
```

`B-SCOPE`で編集範囲を確認し，`B-SLIDE`，`B-MIXED`，`B-POSITIVE`，`B-NEGATIVE`の4ケースで**出力と実行後メモリの両方**を検査する．別入力は一時コピーのデータ定義だけへ適用し，自分のソースは書き換えない．要素数はすべて6，小さな整数で，INT_MINや合計のオーバーフローは対象外である．

`LAYOUT`は実行前のAの配置確認，`OUTPUT`はプログラム出力，`MEMORY`はその実行終了後の6ワードの比較を示す．初期状態をassembleし直したdumpを実行後メモリの代用にしない．GUIでも自分で実行し，終了後のAを観察して記録する．

## 10．コマンドとテスト結果

| コマンド | 処理 | 配布直後の結果 |
| --- | --- | --- |
| `make help` | コマンドと編集対象 | 成功 |
| `make check` | Java・RARS・最小実行・メモリ取得 | 成功 |
| `make examples` | 5ファイル・7ケースの例題 | 成功 |
| `make all` | checkとexamples | 成功 |
| `make test-a` | 課題Aの範囲・命令・動作 | 未置換で非0終了 |
| `make test-b` | 課題Bの範囲・出力・実メモリ | 未実装で非0終了 |
| `make test` | A・Bの両方を実行してまとめる | 未完成で非0終了 |
| `make gui` | 対話画面を開く | 自分で操作して閉じる |
| `make clean` | 管理対象のログ・一時ファイルを削除 | Java・RARSなしでも成功 |

`PASS`はその検査の合格，`FAIL`は不一致，`UNFINISHED`は未完成を表す．`ENV-... FAIL`はツール配置・版などの環境不良である．表示した実測値と理由を読む．プログラムが自分で`PASS`を表示しただけでは合格にならない．

補助スクリプトは0＝成功，1＝課題・実行・比較の不合格，2＝環境や基盤のエラーを基本にする．GNU Makeはレシピが失敗すると自身の非0コード（通常2）を返すため，スクリプトの終了コードと同一とは限らない．

各実行は`build/run.*`に独立したログを残す．`stdout.txt`はプログラム出力，`stderr.txt`はRARSの診断，`*.hex`は実メモリ，`*.dec`はその10進表示である．診断は捨てず，開始・終了時刻，実行引数，Java PID，終了コードも保存する．出力比較はCRLFだけをLFへ正規化し，余分な空白や改行欠落は許容しない．

命令数上限100,000，1回のJava起動あたり実時間上限20秒，出力サイズ上限を設けている．無限ループ，入力待ち，例外，上限到達，dump欠落は成功にしない．複数の基本命令を使う通常の課題には十分な余裕がある．制限に達した場合はループの更新と終了条件を確認する．

テストは既知のケースを確認するもので，あらゆるハードコードや実装条件違反を完全に証明・排除するものではない．`lw`や`sw`という文字の存在だけで正しい実装とは判定しない．アルゴリズムと説明の整合は教員・TAも確認する．

`make clean`は実行用の印がある`build/run.*`だけを削除し，`build/.gitkeep`，課題ソース，ツール，リポジトリ外のレポートを保持する．記録を残す場合は必要な実測結果を先にレポートへ整理する．

## 11．レポート・提出・評価

締切は**2027年1月8日（金）23:59，日本時間**．Science Tokyo LMSへ，`学籍番号_ex03_code.zip`と`学籍番号_ex03_report.pdf`を提出する．`学籍番号`を自分の番号へ置き換える．

[正式な記入ガイド](report/README.md)を読み，[Word雛形](report/ex03-report-template.docx)を**リポジトリ外へコピー**して`学籍番号_ex03_report.docx`として記入する．Wordファイル自体は提出しない．LaTeX等でも同じ設問・表の項目を維持する．

課題Aは編集前のBasic列と自分の基本命令の対応，オペランド，同じ働きになる理由，テストの実測結果を記録する．課題Bは処理概要，使用レジスタ，コードとの対応，実際の出力，Run終了直後・Reset／再Assemble前のAの6要素，テスト結果を示す．ソース全文をレポートへ重複掲載せず，説明に必要な短い箇所だけ示す．

スクリーンショットは任意で，有無や枚数を評価しない．必要な命令，出力，配列値は読み取れるテキストまたは表で記録する．画像だけで必須回答を代用できないが，補足画像は禁止しない．

Word等からPDFへ出力し，全ページの文字・表・コードを開いて確認する．

### コードZIPの作成

提出するZIPは，次の2ファイルだけを入れ，`tasks/`の階層を保持する．

```text
学籍番号_ex03_code.zip
└── tasks/
    ├── pseudo_task.s
    └── array_task.s
```

**GUIで作る場合**：リポジトリ外に空の提出用フォルダーを作り，その中に`tasks`フォルダーを作る．編集した`pseudo_task.s`と`array_task.s`の2ファイルだけをコピーする．この`tasks`フォルダーを選び，OSの「圧縮」「ZIPファイルに圧縮」等を使う．できたZIPを`学籍番号_ex03_code.zip`へ改名する．macOSではFinder，Windowsではエクスプローラー，GNU/Linuxでは利用環境のファイルマネージャーの圧縮機能を使える．追加ソフトウェアは必須ではない．

任意のコマンド例（教材ルートで実行）．`学籍番号`を自分の番号へ置き換え，出力先に同名のZIPがないことを確認する．既存ZIPへ追記しない．

macOS／GNU/Linuxで`zip`が使える場合：

```sh
zip -X "../学籍番号_ex03_code.zip" tasks/pseudo_task.s tasks/array_task.s
```

Windows PowerShell：

```powershell
Compress-Archive -LiteralPath .\tasks -DestinationPath ..\学籍番号_ex03_code.zip
```

PowerShell例の実行前に，`tasks`の中身が上記2ファイルだけであることを確認する．追加ファイルがある場合は，GUIの手順でリポジトリ外に2ファイルだけをコピーして圧縮する．

**作成後は必ず別の空フォルダーへZIPを展開する**．最上位に`tasks`があり，その中に上記2ファイルだけがあることを確認する．2ファイルを開き，自分の最終コードと一致することも確認する．`.DS_Store`や`__MACOSX`等の自動付加ファイルが見える場合も取り除き，2ファイルだけで作り直す．`zip`の例は指定した2ファイルだけを格納する．

`examples/`，`tests/`，`tools/`，`build/`，`report/`，`.git/`，README，Makefile，RARS JAR，ログ，dump，別の解答資料やその他の教材ファイルは含めない．

### 提出前チェックと評価

`make test-a`と`make test-b`を実行して結果を記録し，コードとレポートの内容，必須欄，ZIP展開後の中身，PDFの表示，提出名，締切を確認する．詳しいチェックリストは[記入ガイド](report/README.md#10提出前チェック)を参照する．

テスト合格は正式採点や満点を保証しない．教員・TAがコード，条件遵守，説明と実測値の整合を確認する．文章量や装飾は評価対象外である．詳細配点と模範解答は非公開．遅延提出は減点対象だが，具体率を本教材で新たに定めるものではない．

## 12．トラブルシューティング

- `ENV-LOCALE`が失敗：Java／RARS用のUTF-8 localeを自動検出できなかった．表示された`Checked`と`build/run.*/locale-probes.txt`を教員・TAへ示し，利用環境を確認する．通常はlocaleやJavaの保存先を手動設定する必要はない．
- Javaが見つからない／版が出ない：`JAVA`，`JAVA_HOME`，PATHの順に確認する．明示した誤設定を直すか，現在の端末から解除する．起動用スタブの案内だけではJavaが動いたことにならない．
- JARがない／SHA不一致：採用されたパスを確認する．公式v1.6のJARを使い，ダウンロード途中のHTMLやcontinuous buildと混同しない．既存ファイルを無断で上書きしない．
- WindowsでMakeがない：準備したPowerShellのウィンドウで別名を設定する．スクリプト実行が組織のポリシーで拒否される場合は，エラーを保持して教員・TAへ相談する．本教材は実行ポリシーを変更しない．
- ラベル重複：1ファイルずつ開き，ディレクトリ全体をまとめてassembleする設定をオフにする．
- `A-SCOPE`／`B-SCOPE`が失敗：マーカー，順序，指定範囲外の変更を確認する．自分のコードを消さず，必要なら教員・TAへ相談する．
- 課題Aの動作はPASSだが全体はFAIL：配布版の疑似命令が残っていないか，別の疑似形式を使っていないか確認する．
- 課題BのOUTPUTはPASS，MEMORYはFAIL：表示しただけで元のAへ書き戻していない可能性がある．同じ要素の保存先と`sw`を確認する．
- 課題BのOUTPUTがFAIL：半角空白の個数，行頭・行末の空白，両行末の改行を確認する．ログのexpected／actualは実際のバイト列で比較している．
- メモリが元に戻る：Reset・再Assembleの前に，Run終了直後のData Segmentを読む．
- タイムアウト／命令数上限：ループのカウンタ，アドレス更新，終了条件を確認する．診断と該当ケースのログを教員・TAへ示す．

## 13．出典

- [RARS v1.6 Release](https://github.com/TheThirdOne/rars/releases/tag/v1.6)
- [RARS：Using the command line](https://github.com/TheThirdOne/rars/wiki/Using-the-command-line)
- [RARS：Environment Calls](https://github.com/TheThirdOne/rars/wiki/Environment-Calls)
- 授業スライド「計算機システム（演習）」2026年度第3回．
