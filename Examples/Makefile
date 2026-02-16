# Examples Makefile: test SPM Extended Plugin with local OpenSPMRegistry.
# Run from Examples/: make <target>
# Or from repo root: make -C Examples <target>
#
# Prerequisites: Swift, Go. For test-publish: run "make registry-start" first.
# Self-signed cert at https://localhost:8080 may require accepting in browser or using insecure flags.

REGISTRY_PORT := 12345
# Use HTTP for local registry to avoid TLS/self-signed cert errors.
REGISTRY_URL := http://localhost:$(REGISTRY_PORT)
SCOPE := sample
PACKAGE_NAME := SamplePackage
PACKAGE_ID := $(SCOPE).$(PACKAGE_NAME)
VERSION := 1.0.0

OPENSPM_REGISTRY := OpenSPMRegistry
SAMPLE_PACKAGE := SamplePackage
DEMO_LIB := DemoLib
DEMO_LIB_ID := $(SCOPE).$(DEMO_LIB)
PID_FILE := .registry.pid

.PHONY: submodule deps registry-start registry-stop resolve publish-demo test-metadata test-publish test-outdated test-dry-run help

# Default target when only "make" is invoked.
.DEFAULT_GOAL := help

# Ensure OpenSPMRegistry submodule is initialized and updated.
submodule deps:
	git submodule update --init --recursive $(OPENSPM_REGISTRY)

# Start OpenSPMRegistry in the background (go run from submodule). Uses port $(REGISTRY_PORT) via config.local.yml.
registry-start: submodule
	@$(MAKE) registry-stop 2>/dev/null || true
	@if [ -f $(PID_FILE) ] && kill -0 $$(cat $(PID_FILE)) 2>/dev/null; then \
		echo "Registry already running (PID $$(cat $(PID_FILE)))"; \
		exit 0; \
	fi
	sed 's/port: 8080/port: $(REGISTRY_PORT)/' $(OPENSPM_REGISTRY)/config.yml > $(OPENSPM_REGISTRY)/config.local.yml
	(cd $(OPENSPM_REGISTRY) && go run main.go -v) & echo $$! > $(PID_FILE)
	@sleep 1 && echo "Registry started on port $(REGISTRY_PORT) (PID $$(cat $(PID_FILE))). Stop with: make registry-stop"

# Stop the registry process started by registry-start. If no PID file, tries to kill process on port $(REGISTRY_PORT).
registry-stop:
	@if [ -f $(PID_FILE) ]; then \
		pid=$$(cat $(PID_FILE)); \
		if kill -0 $$pid 2>/dev/null; then kill $$pid; echo "Stopped registry (PID $$pid)"; fi; \
		rm -f $(PID_FILE); \
	else \
		pid=$$(lsof -ti :$(REGISTRY_PORT) 2>/dev/null); \
		if [ -n "$$pid" ]; then kill $$pid 2>/dev/null; echo "Stopped process on port $(REGISTRY_PORT) (PID $$pid)"; fi; \
	fi

# Resolve SamplePackage dependencies (required for outdated and for plugin).
# Sets local registry URL so registry deps (e.g. sample.DemoLib) resolve from it.
resolve: submodule
	cd $(SAMPLE_PACKAGE) && swift package-registry set $(REGISTRY_URL) --allow-insecure-http && \
	swift package resolve

# Create Package.json and package-metadata.json only (no publish).
test-metadata: submodule
	cd $(SAMPLE_PACKAGE) && swift package --disable-sandbox registry metadata create --vv

# Publish sample package to local registry. Requires registry running (make registry-start).
test-publish: submodule
	cd $(SAMPLE_PACKAGE) && swift package-registry set $(REGISTRY_URL) --allow-insecure-http && \
	swift package --disable-sandbox registry publish $(PACKAGE_ID) $(VERSION) --url $(REGISTRY_URL) --allow-insecure-http

# Publish DemoLib 1.0.0 and 1.1.0 to local registry so test-outdated can show updates.
# Requires registry running (make registry-start). Removes existing DemoLib from registry first to avoid 409 on re-run.
publish-demo: submodule registry-start
	@rm -rf $(OPENSPM_REGISTRY)/files/$(SCOPE)/$(DEMO_LIB)
	cd $(DEMO_LIB) && swift package-registry set $(REGISTRY_URL) --allow-insecure-http && \
	swift package --disable-sandbox registry publish $(DEMO_LIB_ID) 1.0.0 --url $(REGISTRY_URL) --allow-insecure-http && \
	swift package --disable-sandbox registry publish $(DEMO_LIB_ID) 1.1.0 --url $(REGISTRY_URL) --allow-insecure-http
	@echo "DemoLib 1.0.0 and 1.1.0 published. Run make test-outdated to see updates."

# List available versions of dependencies. Runs publish-demo then resolve so updates are visible.
test-outdated: publish-demo resolve
	cd $(SAMPLE_PACKAGE) && swift package --disable-sandbox outdated --registry-url $(REGISTRY_URL)

# Prepare publish files without uploading.
test-dry-run: submodule
	cd $(SAMPLE_PACKAGE) && swift package --disable-sandbox registry publish $(PACKAGE_ID) $(VERSION) --url $(REGISTRY_URL) --allow-insecure-http --dry-run

help:
	@echo "Run from Examples/: make <target>"
	@echo "Or from repo root: make -C Examples <target>"
	@echo ""
	@echo "Targets:"
	@echo "  submodule       - Init/update OpenSPMRegistry git submodule"
	@echo "  registry-start  - Start OpenSPMRegistry in background (go run main.go)"
	@echo "  registry-stop   - Stop the registry started by registry-start"
	@echo "  resolve         - swift package resolve in SamplePackage (sets local registry)"
	@echo "  publish-demo    - Publish DemoLib 1.0.0 and 1.1.0 to registry (for outdated demo)"
	@echo "  test-metadata   - Create Package.json and package-metadata.json"
	@echo "  test-publish    - Publish sample package to local registry (run registry-start first)"
	@echo "  test-outdated   - List dependency updates (starts registry, publishes DemoLib, then outdated)"
	@echo "  test-dry-run    - Prepare publish without uploading"
	@echo "  help            - This message"
