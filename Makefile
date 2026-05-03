SHELL := /bin/bash

APP_NAME := Probe
PROJECT := Probe.xcodeproj
SCHEME := Probe
DERIVED_DATA := .derivedData
ARCHIVE_DIR := .archives
ARCHIVE_PATH := $(ARCHIVE_DIR)/$(APP_NAME).xcarchive
APPLICATIONS_DIR ?= /Applications

CONFIGURATION ?= Debug
RELEASE_CONFIGURATION ?= Release
DESTINATION ?= platform=macOS
ARCHIVE_DESTINATION ?= generic/platform=macOS

XCODEBUILD ?= xcodebuild
XCODEGEN ?= xcodegen

BUILT_APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/$(APP_NAME).app
RELEASE_APP := $(DERIVED_DATA)/Build/Products/$(RELEASE_CONFIGURATION)/$(APP_NAME).app
INSTALLED_APP := $(APPLICATIONS_DIR)/$(APP_NAME).app

.PHONY: help generate build build-release archive install test clean check-xcodegen

help:
	@printf "Probe build shortcuts\n\n"
	@printf "  make generate       Generate $(PROJECT) with XcodeGen\n"
	@printf "  make build          Build $(APP_NAME) ($(CONFIGURATION))\n"
	@printf "  make build-release  Build $(APP_NAME) ($(RELEASE_CONFIGURATION))\n"
	@printf "  make archive        Create $(ARCHIVE_PATH)\n"
	@printf "  make install        Build release and install to $(APPLICATIONS_DIR)\n"
	@printf "  make test           Run the app test scheme\n"
	@printf "  make clean          Remove derived data and local archives\n"

generate: check-xcodegen
	$(XCODEGEN) generate

build: generate
	$(XCODEBUILD) \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		build
	@printf "\nBuilt app: $(BUILT_APP)\n"

build-release: generate
	$(XCODEBUILD) \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(RELEASE_CONFIGURATION)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		build
	@printf "\nBuilt app: $(RELEASE_APP)\n"

archive: generate
	@mkdir -p "$(ARCHIVE_DIR)"
	$(XCODEBUILD) \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(RELEASE_CONFIGURATION)" \
		-destination "$(ARCHIVE_DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		-archivePath "$(ARCHIVE_PATH)" \
		archive
	@printf "\nArchive: $(ARCHIVE_PATH)\n"

install: build-release
	@test -d "$(RELEASE_APP)" || { printf "Missing built app: $(RELEASE_APP)\n"; exit 1; }
	@printf "Installing $(RELEASE_APP) to $(INSTALLED_APP)\n"
	@rm -rf "$(INSTALLED_APP)"
	@ditto "$(RELEASE_APP)" "$(INSTALLED_APP)"
	@printf "Installed: $(INSTALLED_APP)\n"

test: generate
	$(XCODEBUILD) \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Debug \
		-destination "$(DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		test

clean:
	@rm -rf "$(DERIVED_DATA)" "$(ARCHIVE_DIR)"

check-xcodegen:
	@command -v "$(XCODEGEN)" >/dev/null || { \
		printf "xcodegen is required. Install it with: brew install xcodegen\n"; \
		exit 1; \
	}
