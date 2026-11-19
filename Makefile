# Peek — common tasks. `make run` builds a Release app and launches it.
APP := build/Build/Products/Release/Peek.app
XCB := xcodebuild -project Peek.xcodeproj -scheme Peek -derivedDataPath build -quiet

.PHONY: build debug run demo stop install-hook uninstall-hook dist site clean

build:            ## Release build
	$(XCB) -configuration Release build

debug:            ## Debug build (adds PEEK_SNAPSHOT and /debug endpoints)
	$(XCB) -configuration Debug build

run: build stop   ## Build and launch
	open $(APP)

demo: build stop  ## Launch with fake agents showing every state
	PEEK_FAKE=1 $(APP)/Contents/MacOS/Peek &

stop:             ## Quit a running Peek
	-@pkill -x Peek || true

install-hook:     ## Route Claude Code permission prompts to Peek
	./scripts/install-hook.sh

uninstall-hook:   ## Remove Peek's hook from ~/.claude/settings.json
	./scripts/uninstall-hook.sh

dist:             ## Universal (arm64 + x86_64) Release zip for GitHub releases
	xcodebuild -project Peek.xcodeproj -scheme Peek -quiet -configuration Release ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO -derivedDataPath build/universal build
	mkdir -p build/dist && rm -f build/dist/Peek.zip
	ditto -c -k --keepParent build/universal/Build/Products/Release/Peek.app build/dist/Peek.zip
	@echo "build/dist/Peek.zip"

site:             ## Run the landing page locally (http://localhost:3000)
	cd site && npm install && npm run dev

clean:
	rm -rf build
