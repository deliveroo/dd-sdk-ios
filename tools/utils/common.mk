# Common helpers for all Makefiles
#
# Usage in other Makefiles:
# ```
# REPO_ROOT := <path to repo root folder>
# include tools/utils/common.mk
# ```

ifndef REPO_ROOT
$(error "REPO_ROOT is not set but it is required. It must resolve to the repo root folder.")
endif

ECHO_TITLE=$(REPO_ROOT)/tools/utils/echo_color.sh --title
ECHO_SUBTITLE=$(REPO_ROOT)/tools/utils/echo_color.sh --subtitle
ECHO_SUBTITLE2=$(REPO_ROOT)/tools/utils/echo_color.sh --subtitle2
ECHO_ERROR=$(REPO_ROOT)/tools/utils/echo_color.sh --err
ECHO_WARNING=$(REPO_ROOT)/tools/utils/echo_color.sh --warn
ECHO_SUCCESS=$(REPO_ROOT)/tools/utils/echo_color.sh --succ

define require_param
    if [ -z "$${$(1)}" ]; then \
        $(ECHO_ERROR) "Error:" "$(1) parameter is required but not provided."; \
        exit 1; \
    fi
endef

CURRENT_GIT_TAG := $(shell $(REPO_ROOT)/tools/utils/current_git.sh --print-tag)
CURRENT_GIT_BRANCH := $(shell $(REPO_ROOT)/tools/utils/current_git.sh --print-branch)
CURRENT_GIT_REF := $(shell $(REPO_ROOT)/tools/utils/current_git.sh --print)
