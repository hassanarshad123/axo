PROJECT := Axo.xcodeproj
SCHEME := Axo
DERIVED := build
APP := $(DERIVED)/Build/Products/Debug/Axo.app

# The pack codes, so `make test` checks the locked buddies' art too. Empty outside Hassan's Mac.
UNLOCK_CODES := $(shell bash $(HOME)/.secrets/bin/secrets.sh get axo 2>/dev/null | sed -n 's/^AXO_PACK_.*_CODE=//p' | paste -sd, -)

.PHONY: help project build test run install packs clean

help: ## Show the commands
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'

project: ## Create the Xcode project from project.yml
	xcodegen generate

build: project ## Build the app (Debug)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED) -destination 'platform=macOS,arch=$(shell uname -m)' build -quiet

test: ## Run the unit tests for the shared code
	AXO_UNLOCK_CODES="$(UNLOCK_CODES)" swift test --package-path Packages/BuddyKit

run: build ## Build and open the app
	open "$(APP)"

install: ## Build Release and install it in /Applications (this Mac only)
	scripts/install-local.sh

packs: ## Lock private/packs/* into the app (codes from ~/.secrets)
	scripts/make-packs.sh

clean: ## Remove build output and the generated project
	rm -rf $(DERIVED) $(PROJECT)
