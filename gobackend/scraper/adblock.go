package scraper

import (
	"regexp"
	"time"
)

const (
	BaseURL     = "https://streamtpday1.xyz"
	EventsURL   = "https://streamtpday1.xyz/eventos.html"
	StatusURL   = "https://streamtpday1.xyz/status.json"
	EventosJSON = "https://streamtpday1.xyz/eventos.json"
	UserAgent   = "Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36"
	Timeout     = 15 * time.Second
)

var (
	adPatterns = []*regexp.Regexp{
		regexp.MustCompile(`(?i)ad[-_]?banner|advertisement|pub|advert`),
		regexp.MustCompile(`(?i)google[-_]?adsense|google[-_]?ads|gads`),
		regexp.MustCompile(`(?i)doubleclick|ads\.google|pagead`),
		regexp.MustCompile(`(?i)popunder|pop[-_]?under`),
		regexp.MustCompile(`(?i)facebook[-_]?pixel|fbpx`),
		regexp.MustCompile(`(?i)amazon[-_]?ads|amzn[-_]?ads`),
		regexp.MustCompile(`(?i)criteo|criteo\.net`),
		regexp.MustCompile(`(?i)outbrain|taboola`),
	}

	blockedDomains = map[string]bool{
		"doubleclick.net":                      true,
		"googlesyndication.com":                 true,
		"pagead2.googlesyndication.com":         true,
		"ads.google.com":                       true,
		"adservice.google.com":                  true,
		"google-analytics.com":                  true,
		"analytics.google.com":                  true,
		"facebook.com":                         true,
		"connect.facebook.net":                  true,
		"amazon-adsystem.com":                   true,
		"criteo.net":                           true,
		"criteo.com":                           true,
		"outbrain.com":                         true,
		"taboola.com":                          true,
		"viglink.com":                          true,
		"everesttech.net":                      true,
		"flixster.com":                         true,
		"scorecardresearch.com":                 true,
		"tracking.publishersperksservices.com":  true,
		"adnxs.com":                            true,
		"rubicdn.com":                          true,
	}
)
