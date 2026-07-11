package main

import (
	"archive/tar"
	"compress/gzip"
	"embed"
	"io"
	"io/fs"
	"net"
	"net/http"
	"net/netip"
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

// defaultPublicBaseURL is the canonical public URL the server is served at.
// It is the fallback when PUBLIC_BASE_URL is unset and the source of BASE for
// every request whose direct peer is not a configured trusted proxy.
const defaultPublicBaseURL = "https://dotfiles.example.com"

// publicBaseURL is the fixed configured canonical base URL embedded into the
// install script. Set from PUBLIC_BASE_URL at startup.
var publicBaseURL = defaultPublicBaseURL

// trustedProxies are the networks whose forwarded headers we honor. Only when a
// request's direct peer (RemoteAddr) falls inside one of these do we reconstruct
// BASE from client-controlled X-Forwarded-* headers. Empty means never trust
// forwarded headers. Set from TRUSTED_PROXY_CIDRS at startup.
var trustedProxies []netip.Prefix

// baseURL returns the canonical public base URL used to build the install
// script and tarball URL. It defaults to the fixed configured publicBaseURL and
// only honors client-supplied X-Forwarded-* / Host when the direct peer is a
// configured trusted proxy. This closes the host-header poisoning -> RCE path:
// an untrusted client reaching the server directly (or through a Host-blind
// cache) can never steer BASE at an attacker-controlled tarball host.
func baseURL(r *http.Request) string {
	if !peerTrusted(r.RemoteAddr) {
		return publicBaseURL
	}
	scheme := "https"
	if proto := r.Header.Get("X-Forwarded-Proto"); proto != "" {
		scheme = proto
	} else if r.TLS == nil {
		scheme = "http"
	}
	host := r.Host
	if fwd := r.Header.Get("X-Forwarded-Host"); fwd != "" {
		host = fwd
	}
	if host == "" {
		return publicBaseURL
	}
	return scheme + "://" + host
}

// peerTrusted reports whether the request's direct peer (RemoteAddr) is within
// one of the configured trusted-proxy CIDRs.
func peerTrusted(remoteAddr string) bool {
	if len(trustedProxies) == 0 {
		return false
	}
	a := parseAddr(remoteAddr)
	if !a.IsValid() {
		return false
	}
	for _, p := range trustedProxies {
		if p.Contains(a) {
			return true
		}
	}
	return false
}

// parseAddr extracts a netip.Addr from a "host:port" RemoteAddr or a bare
// address. Zones and surrounding spaces are stripped; the result is unmapped.
func parseAddr(s string) netip.Addr {
	s = strings.TrimSpace(s)
	if host, _, err := net.SplitHostPort(s); err == nil {
		s = host
	}
	if i := strings.IndexByte(s, '%'); i >= 0 {
		s = s[:i]
	}
	a, err := netip.ParseAddr(s)
	if err != nil {
		return netip.Addr{}
	}
	return a.Unmap()
}

// parseTrustedProxies parses a comma-separated list of CIDRs into masked
// prefixes. Invalid entries are logged and skipped.
func parseTrustedProxies(csv string) []netip.Prefix {
	var out []netip.Prefix
	for _, c := range strings.Split(csv, ",") {
		c = strings.TrimSpace(c)
		if c == "" {
			continue
		}
		p, err := netip.ParsePrefix(c)
		if err != nil {
			log.Warn().Str("cidr", c).Err(err).Msg("ignoring invalid TRUSTED_PROXY_CIDRS entry")
			continue
		}
		out = append(out, p.Masked())
	}
	return out
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
	io.WriteString(w, "dotfiles server "+version()+"\ninstall: curl -fsSL "+baseURL(r)+"/install | bash\n")
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

	if v := strings.TrimSpace(os.Getenv("PUBLIC_BASE_URL")); v != "" {
		publicBaseURL = strings.TrimRight(v, "/")
	}
	trustedProxies = parseTrustedProxies(os.Getenv("TRUSTED_PROXY_CIDRS"))

	mux := http.NewServeMux()
	mux.HandleFunc("/", handleRoot)
	mux.HandleFunc("/install", handleInstall)
	mux.HandleFunc("/nuke", handleNuke)
	mux.HandleFunc("/version", handleVersion)
	mux.HandleFunc("/dotfiles.tar.gz", handleTarball)

	log.Info().Str("addr", addr).Str("version", version()).
		Str("base_url", publicBaseURL).Int("trusted_proxies", len(trustedProxies)).
		Msg("dotfiles server starting")
	srv := &http.Server{
		Addr:              addr,
		Handler:           logMW(mux),
		ReadHeaderTimeout: 5 * time.Second,
	}
	if err := srv.ListenAndServe(); err != nil {
		log.Fatal().Err(err).Msg("server exited")
	}
}
