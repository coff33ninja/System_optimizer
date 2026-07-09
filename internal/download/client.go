package download

import (
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"time"
)

var allowedHosts = map[string]bool{
	"raw.githubusercontent.com": true,
	"github.com":                true,
	"objects.githubusercontent.com": true,
	"api.github.com":            true,
}

var ErrHTTPSRequired = errors.New("only HTTPS downloads allowed")
var ErrHostNotAllowed = errors.New("host not in allowlist")

type ProgressFunc func(downloaded, total int64)

type Client struct {
	httpClient *http.Client
	allowlist  map[string]bool
}

func NewClient() *Client {
	transport := &http.Transport{
		TLSClientConfig: &tls.Config{
			MinVersion: tls.VersionTLS12,
		},
	}
	return &Client{
		httpClient: &http.Client{
			Transport: transport,
			Timeout:   5 * time.Minute,
		},
		allowlist: allowedHosts,
	}
}

func (c *Client) ValidateURL(rawURL string) error {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return fmt.Errorf("invalid URL: %w", err)
	}
	if parsed.Scheme != "https" {
		return ErrHTTPSRequired
	}
	if !c.allowlist[parsed.Host] {
		return fmt.Errorf("%w: %s", ErrHostNotAllowed, parsed.Host)
	}
	return nil
}

func (c *Client) DownloadToFile(rawURL, destPath string, progress ProgressFunc) error {
	if err := c.ValidateURL(rawURL); err != nil {
		return err
	}

	resp, err := c.httpClient.Get(rawURL)
	if err != nil {
		return fmt.Errorf("download failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %d: %s", resp.StatusCode, resp.Status)
	}

	f, err := os.Create(destPath)
	if err != nil {
		return fmt.Errorf("create file: %w", err)
	}
	defer f.Close()

	total := resp.ContentLength
	if progress != nil {
		return copyWithProgress(f, resp.Body, total, progress)
	}

	_, err = io.Copy(f, resp.Body)
	return err
}

func (c *Client) DownloadToMemory(rawURL string) ([]byte, error) {
	if err := c.ValidateURL(rawURL); err != nil {
		return nil, err
	}

	resp, err := c.httpClient.Get(rawURL)
	if err != nil {
		return nil, fmt.Errorf("download failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d: %s", resp.StatusCode, resp.Status)
	}

	return io.ReadAll(resp.Body)
}

func copyWithProgress(dst io.Writer, src io.Reader, total int64, progress ProgressFunc) error {
	buf := make([]byte, 32*1024)
	var downloaded int64

	for {
		n, err := src.Read(buf)
		if n > 0 {
			written, wErr := dst.Write(buf[:n])
			downloaded += int64(written)
			if wErr != nil {
				return wErr
			}
			progress(downloaded, total)
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
	}
	return nil
}
