# SliceSoft — Shared base Makefile
#
# Single source of truth for the standard developer commands across every
# SliceSoft repo. The ss-workstation installer provisions it to a fixed path in
# your home, so it works no matter where a repo is cloned:
#
#     ~/.config/slicesoft/base.mk   (symlink -> this file; a `git pull` in
#                                    ss-workstation updates it live)
#
# Include it from any repo's Makefile:
#
#     SS_BASE ?= $(HOME)/.config/slicesoft/base.mk
#     ifeq ($(wildcard $(SS_BASE)),)
#         $(error SliceSoft base.mk not found — run the ss-workstation setup)
#     endif
#     include $(SS_BASE)
#
#     # ...then add your repo-specific targets (build, run, ...)
#
# Repos tune behavior by setting these BEFORE the include:
#     CLEAN_EXTRA   extra paths for `make clean` to remove

SHELL := /bin/bash
.DEFAULT_GOAL := help

REPO_ROOT ?= $(shell git rev-parse --show-toplevel 2>/dev/null || pwd)
TOOL_VERSIONS_FILE := $(REPO_ROOT)/.tool-versions
CLEAN_EXTRA ?=

# ─── Help ───────────────────────────────────────────────────────────────────────
.PHONY: help
help: ## Show available commands
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# ─── Setup ──────────────────────────────────────────────────────────────────────
.PHONY: setup
setup: install-versions install-deps ## Bootstrap the project (runtimes + deps)
	@echo "Setup complete."

.PHONY: install-versions
install-versions: ## Install runtime versions from .tool-versions (via mise)
	@if [ ! -f "$(TOOL_VERSIONS_FILE)" ]; then \
		echo "No .tool-versions found — skipping mise install"; \
	elif command -v mise &>/dev/null; then \
		mise install; \
	else \
		echo "mise not found. Install it: curl https://mise.run | sh"; exit 1; \
	fi

.PHONY: install-deps
install-deps: ## Install project dependencies (auto-detected)
	@if [ -f go.mod ]; then go mod download; \
	elif [ -f package.json ]; then npm ci; \
	elif [ -f requirements.txt ]; then pip install -r requirements.txt; \
	elif [ -f pyproject.toml ]; then pip install -e .; \
	else echo "No recognized dependency file — skipping"; fi

# ─── Quality ────────────────────────────────────────────────────────────────────
.PHONY: test
test: ## Run tests (auto-detected)
	@if [ -f go.mod ]; then go test ./...; \
	elif [ -f package.json ]; then npm test; \
	elif [ -f pyproject.toml ] || [ -f requirements.txt ]; then python -m pytest; \
	else echo "No test runner detected."; fi

.PHONY: lint
lint: ## Run linter (auto-detected)
	@if [ -f go.mod ]; then \
		command -v golangci-lint &>/dev/null && golangci-lint run ./... || go vet ./...; \
	elif [ -f package.json ] && grep -q '"lint"' package.json; then npm run lint; \
	else echo "No linter detected."; fi

.PHONY: check-secrets
check-secrets: ## Scan for accidentally committed secrets
	@if command -v gitleaks &>/dev/null; then gitleaks detect --source . --no-banner; \
	elif command -v trufflehog &>/dev/null; then trufflehog git file://. --only-verified; \
	else echo "No secrets scanner found. Install gitleaks or trufflehog."; fi

# ─── Clean ──────────────────────────────────────────────────────────────────────
.PHONY: clean
clean: ## Remove build artifacts
	@rm -rf dist/ build/ out/ tmp/ .cache/ $(CLEAN_EXTRA)
	@if [ -f go.mod ]; then go clean ./... 2>/dev/null || true; fi
	@echo "Cleaned."
