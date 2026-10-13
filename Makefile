APP_NAME := RepositoryManager
BUILD_DIR := build

build:
	bash build.sh

install: build
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(BUILD_DIR)/$(APP_NAME).app" /Applications/

test:
	mkdir -p $(BUILD_DIR)
	xcrun swiftc -parse-as-library -o $(BUILD_DIR)/SealedBoxTests tests/SealedBoxTests.swift src/SealedBox.swift
	$(BUILD_DIR)/SealedBoxTests

.PHONY: build install test