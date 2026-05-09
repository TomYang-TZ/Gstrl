.PHONY: build install uninstall run stop restart clean

APP_NAME := Gstrl
APP_BUNDLE := $(APP_NAME).app
INSTALL_DIR := /Applications

build:
	@swift build
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp .build/arm64-apple-macosx/debug/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	@cp Sources/Gstrl/Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	@echo "✓ $(APP_BUNDLE) built"

install: build
	@rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	@cp -R $(APP_BUNDLE) $(INSTALL_DIR)/$(APP_BUNDLE)
	@rm -rf $(APP_BUNDLE)
	@echo "✓ Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"

uninstall:
	@rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	@echo "✓ Uninstalled"

run: install
	@open $(INSTALL_DIR)/$(APP_BUNDLE)

stop:
	@pkill -f $(APP_NAME) 2>/dev/null && echo "✓ Stopped" || echo "Not running"

restart: stop
	@sleep 0.5
	@$(MAKE) run

clean:
	@rm -rf .build $(APP_BUNDLE)
	@echo "✓ Cleaned"
