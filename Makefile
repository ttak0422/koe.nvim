# Unset the nix-provided SDKROOT and build with CommandLineTools (no Xcode required)
SDK := /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk
SWIFTC := env -u SDKROOT DEVELOPER_DIR=/Library/Developer/CommandLineTools swiftc

build: bin/koe-helper

bin/koe-helper: cli/main.swift
	mkdir -p bin
	$(SWIFTC) -O -swift-version 5 -sdk $(SDK) -o $@ $<

test:
	nvim --headless --clean -l test/health.lua
	nvim --headless --clean -l test/smoke.lua

clean:
	rm -rf bin

.PHONY: build test clean
