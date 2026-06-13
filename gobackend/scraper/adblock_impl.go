package scraper

import (
	"net/url"
	"strings"
)

func isAdDomain(urlStr string) bool {
	if urlStr == "" {
		return false
	}
	parsed, err := url.Parse(urlStr)
	if err != nil {
		return false
	}
	domain := strings.ToLower(parsed.Host)
	if blockedDomains[domain] {
		return true
	}
	for blocked := range blockedDomains {
		if strings.HasSuffix(domain, "."+blocked) {
			return true
		}
	}
	return false
}

func IsAdDomain(urlStr string) bool {
	return isAdDomain(urlStr)
}

func IsAdContent(urlStr string) bool {
	lower := strings.ToLower(urlStr)
	for _, pattern := range adPatterns {
		if pattern.MatchString(lower) {
			return true
		}
	}

	adPaths := []string{
		"/googleadservices", "/pagead/", "/ads/", "/advertising/",
		"/advertisement/", "/banner/", "analytics.js", "gtag",
	}
	for _, p := range adPaths {
		if strings.Contains(lower, p) {
			return true
		}
	}
	return false
}
