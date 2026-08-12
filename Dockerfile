# --- build (cross-compiles natively for the target arch, no QEMU) ---
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS build
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY go.mod go.sum* ./
RUN go mod download 2>/dev/null || true
COPY . .
RUN go mod tidy && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags='-s -w' -o /dotfiles-server .

# --- runtime (distroless static: no shell, no package manager) ---
FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=build /dotfiles-server /dotfiles-server
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/dotfiles-server"]
