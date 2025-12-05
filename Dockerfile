# Multi-stage build for minimal image size
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o aicommit .

# Final stage
FROM alpine:latest

# Install git (required dependency)
RUN apk add --no-cache git

# Create non-root user
RUN addgroup -g 1000 aicommit && \
    adduser -D -u 1000 -G aicommit aicommit

# Copy binary from builder
COPY --from=builder /build/aicommit /usr/local/bin/aicommit

# Set up working directory
WORKDIR /repo

# Switch to non-root user
USER aicommit

# Set entrypoint
ENTRYPOINT ["aicommit"]

# Default command (show help)
CMD ["--help"]
