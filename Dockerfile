
FROM golang:1.21-alpine AS builder

WORKDIR /app
RUN go install github.com/stefanprodan/podinfo/cmd/podinfo@latest

FROM gcr.io/distroless/static-debian11
WORKDIR /
COPY --from=builder /go/bin/podinfo .
EXPOSE 9898
ENTRYPOINT ["/podinfo"]
