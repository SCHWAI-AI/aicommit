# Makefile for AICommit

# Variables
BINARY_NAME := aicommit
VERSION := $(shell git describe --tags --always --dirty)
BUILD_TIME := $(shell date -u '+%Y-%m-%d_%H:%M:%S')
LDFLAGS := -ldflags "-s -w -X github.com/SCHW-AI/aicommit/cmd.version=$(VERSION)"
GOFILES := $(shell find . -name "*.go" -type f -not -path "./vendor/*")

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

.PHONY: all build clean test install uninstall run fmt vet lint release-dry release help

## Default target
all: test build

## Build the binary
build:
	@echo "$(GREEN)Building $(BINARY_NAME)...$(NC)"
	@go build $(LDFLAGS) -o $(BINARY_NAME) .
	@echo "$(GREEN)Build complete!$(NC)"

## Build for all platforms
build-all:
	@echo "$(GREEN)Building for all platforms...$(NC)"
	@GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY_NAME)-darwin-amd64 .
	@GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o dist/$(BINARY_NAME)-darwin-arm64 .
	@GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY_NAME)-linux-amd64 .
	@GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o dist/$(BINARY_NAME)-linux-arm64 .
	@GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY_NAME)-windows-amd64.exe .
	@echo "$(GREEN)Multi-platform build complete!$(NC)"

## Clean build artifacts
clean:
	@echo "$(YELLOW)Cleaning...$(NC)"
	@go clean
	@rm -f $(BINARY_NAME)
	@rm -rf dist/
	@rm -rf coverage/
	@echo "$(GREEN)Clean complete!$(NC)"

## Run tests
test:
	@echo "$(GREEN)Running tests...$(NC)"
	@go test -v -race -coverprofile=coverage.txt -covermode=atomic ./...
	@echo "$(GREEN)Tests complete!$(NC)"

## Run tests with coverage report
test-coverage:
	@echo "$(GREEN)Running tests with coverage...$(NC)"
	@mkdir -p coverage
	@go test -v -race -coverprofile=coverage/coverage.txt -covermode=atomic ./...
	@go tool cover -html=coverage/coverage.txt -o coverage/coverage.html
	@echo "$(GREEN)Coverage report generated at coverage/coverage.html$(NC)"

## Install the binary to $GOPATH/bin
install: build
	@echo "$(GREEN)Installing $(BINARY_NAME)...$(NC)"
	@go install $(LDFLAGS) .
	@echo "$(GREEN)Installation complete!$(NC)"

## Uninstall the binary from $GOPATH/bin
uninstall:
	@echo "$(YELLOW)Uninstalling $(BINARY_NAME)...$(NC)"
	@rm -f $(GOPATH)/bin/$(BINARY_NAME)
	@echo "$(GREEN)Uninstall complete!$(NC)"

## Run the application
run: build
	@./$(BINARY_NAME)

## Format the code
fmt:
	@echo "$(GREEN)Formatting code...$(NC)"
	@gofmt -s -w $(GOFILES)
	@goimports -w $(GOFILES)
	@echo "$(GREEN)Format complete!$(NC)"

## Run go vet
vet:
	@echo "$(GREEN)Running go vet...$(NC)"
	@go vet ./...
	@echo "$(GREEN)Vet complete!$(NC)"

## Run linter
lint:
	@echo "$(GREEN)Running linter...$(NC)"
	@if command -v golangci-lint > /dev/null; then \
		golangci-lint run; \
	else \
		echo "$(YELLOW)golangci-lint not installed, skipping...$(NC)"; \
		echo "$(YELLOW)Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest$(NC)"; \
	fi
	@echo "$(GREEN)Lint complete!$(NC)"

## Run security scan
security:
	@echo "$(GREEN)Running security scan...$(NC)"
	@if command -v gosec > /dev/null; then \
		gosec ./...; \
	else \
		echo "$(YELLOW)gosec not installed, skipping...$(NC)"; \
		echo "$(YELLOW)Install with: go install github.com/securego/gosec/v2/cmd/gosec@latest$(NC)"; \
	fi
	@echo "$(GREEN)Security scan complete!$(NC)"

## Update dependencies
deps:
	@echo "$(GREEN)Updating dependencies...$(NC)"
	@go get -u ./...
	@go mod tidy
	@go mod verify
	@echo "$(GREEN)Dependencies updated!$(NC)"

## Generate mocks
mock:
	@echo "$(GREEN)Generating mocks...$(NC)"
	@if command -v mockgen > /dev/null; then \
		go generate ./...; \
	else \
		echo "$(YELLOW)mockgen not installed, skipping...$(NC)"; \
		echo "$(YELLOW)Install with: go install github.com/golang/mock/mockgen@latest$(NC)"; \
	fi
	@echo "$(GREEN)Mock generation complete!$(NC)"

## Run benchmarks
bench:
	@echo "$(GREEN)Running benchmarks...$(NC)"
	@go test -bench=. -benchmem ./...
	@echo "$(GREEN)Benchmarks complete!$(NC)"

## Check code quality (fmt, vet, lint, test)
check: fmt vet lint test
	@echo "$(GREEN)All checks passed!$(NC)"

## Create a release build (dry run)
release-dry:
	@echo "$(GREEN)Running release (dry run)...$(NC)"
	@if command -v goreleaser > /dev/null; then \
		goreleaser release --snapshot --clean; \
	else \
		echo "$(RED)goreleaser not installed$(NC)"; \
		echo "$(YELLOW)Install with: go install github.com/goreleaser/goreleaser@latest$(NC)"; \
	fi

## Create a release
release:
	@echo "$(GREEN)Creating release...$(NC)"
	@if command -v goreleaser > /dev/null; then \
		goreleaser release --clean; \
	else \
		echo "$(RED)goreleaser not installed$(NC)"; \
		echo "$(YELLOW)Install with: go install github.com/goreleaser/goreleaser@latest$(NC)"; \
	fi

## Setup development environment
setup:
	@echo "$(GREEN)Setting up development environment...$(NC)"
	@go mod download
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@go install github.com/securego/gosec/v2/cmd/gosec@latest
	@go install github.com/golang/mock/mockgen@latest
	@go install github.com/goreleaser/goreleaser@latest
	@echo "$(GREEN)Setup complete!$(NC)"

## Docker build
docker-build:
	@echo "$(GREEN)Building Docker image...$(NC)"
	@docker build -t ghcr.io/SCHW-AI/aicommit:local .
	@echo "$(GREEN)Docker build complete!$(NC)"

## Docker run
docker-run: docker-build
	@docker run --rm -v $(PWD):/repo ghcr.io/SCHW-AI/aicommit:local

## Show version
version:
	@echo "$(GREEN)Version: $(VERSION)$(NC)"

## Show help
help:
	@echo "$(GREEN)AICommit Makefile$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC)"
	@echo "  make [target]"
	@echo ""
	@echo "$(YELLOW)Targets:$(NC)"
	@awk '/^##/ { \
		getline target; \
		gsub(/^[^:]*:/, "", target); \
		gsub(/^## /, "", $$0); \
		printf "  $(GREEN)%-20s$(NC) %s\n", target, $$0 \
	}' $(MAKEFILE_LIST) | grep -v '^$$'
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make build          # Build the binary"
	@echo "  make test          # Run tests"
	@echo "  make install       # Install to GOPATH/bin"
	@echo "  make check         # Run all quality checks"
	@echo "  make release-dry   # Test release process"
