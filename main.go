package main

import (
	"archive/tar"
	"compress/gzip"
	"embed"
	"io"
	"io/fs"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

//go:embed all:payload
var payloadFS embed.FS

//go:embed install.sh
var installScript string

//go:embed nuke.sh
var nukeScript string

//go:embed VERSION
var versionRaw string

func version() string { return strings.TrimSpace(versionRaw) }

// baseURL reconstructs the public URL the client used, honoring a reverse proxy.
func baseURL(r *http.Request) string {
	scheme := "http"
	if proto := r.Header.Get("X-Forwarded-Proto"); proto != "" {
		scheme = proto
	} else if r.TLS != nil {
		scheme = "https"
	}
	host := r.Host
	if fwd := r.Header.Get("X-Forwarded-Host"); fwd != "" {
		host = fwd
	}
	return scheme + "://" + host
}

func handleInstall(w http.ResponseWriter, r *http.Request) {
	body := strings.ReplaceAll(installScript, "@@BASE@@", baseURL(r))
	w.Header().Set("Content-Type", "text/x-shellscript; charset=utf-8")
	io.WriteString(w, body)
}

func handleNuke(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/x-shellscript; charset=utf-8")
	io.WriteString(w, nukeScript)
}

func handleVersion(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	io.WriteString(w, version())
}

// handleTarball streams the embedded payload/ as a gzipped tar, with entry names
// relative to $HOME (the "payload/" prefix stripped) so `tar -C $HOME` lands right.
func handleTarball(w http.ResponseWriter, r *http.Request) {
	sub, err := fs.Sub(payloadFS, "payload")
	if err != nil {
		http.Error(w, "payload unavailable", http.StatusInternalServerError)
		log.Error().Err(err).Msg("fs.Sub payload")
		return
	}
	w.Header().Set("Content-Type", "application/gzip")
	w.Header().Set("Content-Disposition", `attachment; filename="dotfiles.tar.gz"`)

	gz := gzip.NewWriter(w)
	defer gz.Close()
	tw := tar.NewWriter(gz)
	defer tw.Close()

	err = fs.WalkDir(sub, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || path == "." {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		hdr := &tar.Header{
			Name:    path,
			Mode:    0o644,
			Size:    info.Size(),
			ModTime: info.ModTime(),
		}
		if strings.HasSuffix(path, ".sh") {
			hdr.Mode = 0o755
		}
		if err := tw.WriteHeader(hdr); err != nil {
			return err
		}
		f, err := sub.Open(path)
		if err != nil {
			return err
		}
		defer f.Close()
		_, err = io.Copy(tw, f)
		return err
	})
	if err != nil {
		log.Error().Err(err).Msg("build tarball")
	}
}

func handleRoot(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	io.WriteString(w, "dotfiles server "+version()+"\ninstall: curl -fsSL "+baseURL(r)+"/install | sh\n")
}

func logMW(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Info().Str("method", r.Method).Str("path", r.URL.Path).
			Str("remote", r.RemoteAddr).Dur("dur", time.Since(start)).Msg("req")
	})
}

func main() {
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr, TimeFormat: time.RFC3339})

	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8080"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", handleRoot)
	mux.HandleFunc("/install", handleInstall)
	mux.HandleFunc("/nuke", handleNuke)
	mux.HandleFunc("/version", handleVersion)
	mux.HandleFunc("/dotfiles.tar.gz", handleTarball)

	log.Info().Str("addr", addr).Str("version", version()).Msg("dotfiles server starting")
	srv := &http.Server{
		Addr:              addr,
		Handler:           logMW(mux),
		ReadHeaderTimeout: 5 * time.Second,
	}
	if err := srv.ListenAndServe(); err != nil {
		log.Fatal().Err(err).Msg("server exited")
	}
}
