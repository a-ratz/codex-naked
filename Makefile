PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: all check test test-codex test-claude lint install uninstall

all: check

check: lint test

test: test-codex test-claude

test-codex:
	bash test/codex-naked-test.sh

test-claude:
	bash test/claude-naked-test.sh

lint:
	bash -n bin/codex-naked
	bash -n bin/claude-naked
	bash -n test/codex-naked-test.sh
	bash -n test/claude-naked-test.sh
	sh -n install.sh
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck bin/codex-naked bin/claude-naked \
			test/codex-naked-test.sh test/claude-naked-test.sh install.sh; \
	else \
		echo "shellcheck not found; skipped"; \
	fi

install:
	install -d "$(BINDIR)"
	install -m 755 bin/codex-naked "$(BINDIR)/codex-naked"
	install -m 755 bin/claude-naked "$(BINDIR)/claude-naked"

uninstall:
	rm -f "$(BINDIR)/codex-naked"
	rm -f "$(BINDIR)/claude-naked"
