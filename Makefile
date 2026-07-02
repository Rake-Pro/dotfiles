IMAGE ?= ghcr.io/rake-pro/dotfiles
VERSION := $(shell cat VERSION)

.PHONY: run build tidy docker-build docker-push release tar-test

run:            ## run the server locally on :8080
	go run .

build:          ## build the binary
	go mod tidy
	CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o dotfiles-server .

tidy:
	go mod tidy

docker-build:   ## build the container image, tagged with VERSION and latest
	docker build -t $(IMAGE):$(VERSION) -t $(IMAGE):latest .

docker-push:    ## push both tags to GHCR
	docker push $(IMAGE):$(VERSION)
	docker push $(IMAGE):latest

release: docker-build docker-push  ## bump VERSION by hand first, then: make release

tar-test:       ## inspect the payload tarball the server would serve
	@go run . & sleep 1 ; curl -s localhost:8080/dotfiles.tar.gz | tar -tzf - ; kill %1
