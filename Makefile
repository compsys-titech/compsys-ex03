# GNU Make 3.81以降．処理はOS標準のシェルへ委譲する．
.DEFAULT_GOAL := help
export JAVA JAVA_HOME RARS_JAR COMPSYS_TOOLS

ifeq ($(OS),Windows_NT)
SHELL := cmd.exe
RUN = powershell.exe -NoProfile -File tools/run.ps1
else
SHELL := /bin/sh
RUN = /bin/sh ./tools/run.sh
endif

.PHONY: help check examples test-a test-b test all clean gui
help check examples test-a test-b test all clean gui:
	@$(RUN) $@
