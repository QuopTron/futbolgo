package scraper

import (
	"fmt"
	"regexp"
	"strings"
)

var (
	playbackURLRe  = regexp.MustCompile(`var\s+playbackURL\s*=\s*"([^"]+)"`)
	streamDomainRe = regexp.MustCompile(`streamtp[a-z0-9.-]+`)
	hlsRe          = regexp.MustCompile(`https?://[^"'\s]+\.m3u8[^"'\s]*`)
	iframeRe       = regexp.MustCompile(`<iframe[^>]+src="([^"]+)"`)
)

func ResolveStreamURL(proxyURL string) (string, error) {
	lowerURL := strings.ToLower(proxyURL)
	if strings.Contains(lowerURL, "sudamericaplay") || strings.Contains(lowerURL, "histats") {
		return "", fmt.Errorf("URL no soportada para resolución: página con scripts anti-framekill")
	}

	html, err := fetchURL(proxyURL)
	if err != nil {
		return "", err
	}

	match := playbackURLRe.FindStringSubmatch(html)
	if len(match) > 1 {
		rawURL := strings.ReplaceAll(match[1], `\/`, `/`)
		if strings.Contains(rawURL, ".m3u8") {
			return rawURL, nil
		}
	}

	if m := hlsRe.FindString(html); m != "" {
		return m, nil
	}

	if m := iframeRe.FindStringSubmatch(html); len(m) > 1 {
		if !isAdDomain(m[1]) && !IsAdContent(m[1]) {
			return ResolveStreamURL(m[1])
		}
	}

	return "", fmt.Errorf("no se pudo resolver el stream desde: %s", proxyURL)
}
