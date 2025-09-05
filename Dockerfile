# Dockerfile

# Use the official Golang image to build the application
FROM golang:1.21-alpine AS builder

WORKDIR /app
# Download Podinfo source code
RUN go install github.com/stefanprodan/podinfo/cmd/podinfo@latest

# Use a minimal, non-root base image for the final container
FROM gcr.io/distroless/static-debian11
WORKDIR /
COPY --from=builder /go/bin/podinfo .
# Expose the port podinfo listens on
EXPOSE 9898
# Set the entrypoint for the container
ENTRYPOINT ["/podinfo"]
