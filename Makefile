SHELL := /bin/bash

CXX ?= g++
CXXFLAGS ?= -std=c++23

ARTIFACTS_DIR := .artifacts
CHAPTER_FILES := $(notdir $(wildcard ch*))

BLUE := \033[1;94m
GREEN := \033[0;32m
RED := \033[0;31m
RESET := \033[0m

.PHONY: clean $(CHAPTER_FILES)

$(CHAPTER_FILES):
	@set -euo pipefail; \
	chapter="$@"; \
	mkdir -p "$(ARTIFACTS_DIR)"; \
	rm -f "$(ARTIFACTS_DIR)/$${chapter}_CB"*; \
	awk -v dir="$(ARTIFACTS_DIR)" -v chapter="$$chapter" '\
	BEGIN { in_block = 0; block = 0; } \
	/^<c\+\+>[[:space:]]*$$/ { \
		if (in_block) { \
			printf("nested <c++> block in %s at line %d\n", chapter, NR) > "/dev/stderr"; \
			exit 1; \
		} \
		in_block = 1; \
		start_line = NR + 1; \
		file = sprintf("%s/%s_CB%d", dir, chapter, block); \
		print "#line " start_line " \"" chapter "\"" > file; \
		next; \
	} \
	/^<\/c\+\+>[[:space:]]*$$/ { \
		if (!in_block) { \
			printf("stray </c++> block terminator in %s at line %d\n", chapter, NR) > "/dev/stderr"; \
			exit 1; \
		} \
		close(file); \
		block++; \
		in_block = 0; \
		next; \
	} \
	in_block { print >> file; } \
	END { \
		if (in_block) { \
			printf("unclosed <c++> block in %s\n", chapter) > "/dev/stderr"; \
			exit 1; \
		} \
		print block > sprintf("%s/%s.count", dir, chapter); \
	}' "$$chapter"; \
	count="$$(cat "$(ARTIFACTS_DIR)/$${chapter}.count")"; \
	rm -f "$(ARTIFACTS_DIR)/$${chapter}.count"; \
	if [[ "$$count" -eq 0 ]]; then \
		printf 'No <c++> blocks found in %s\n' "$$chapter"; \
		exit 0; \
	fi; \
	for ((i = 0; i < count; i++)); do \
		src="$(ARTIFACTS_DIR)/$${chapter}_CB$$i"; \
		bin="$(ARTIFACTS_DIR)/$${chapter}_CB$$i.bin"; \
		log="$(ARTIFACTS_DIR)/$${chapter}_CB$$i.log"; \
		printf "$(BLUE)[-] %s Code Block %d:$(RESET)\n" "$$chapter" "$$i"; \
		if "$(CXX)" $(CXXFLAGS) -x c++ "$$src" -o "$$bin" >"$$log" 2>&1; then \
			if [[ -s "$$log" ]]; then \
				sed 's/^/\t/' "$$log"; \
			fi; \
			if "$$bin" >"$$log" 2>&1; then \
				if [[ -s "$$log" ]]; then \
					sed 's/^/\t/' "$$log"; \
				fi; \
				printf "$(GREEN)[+] Completed Execution$(RESET)\n"; \
			else \
				sed 's/^/\t/' "$$log"; \
				printf "$(RED)[!] execution failed$(RESET)\n"; \
			fi; \
		else \
			sed 's/^/\t/' "$$log"; \
			printf "$(RED)[!] failed to compile$(RESET)\n"; \
		fi; \
		printf '\n'; \
	done

clean:
	@rm -rf "$(ARTIFACTS_DIR)"
