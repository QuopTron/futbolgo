package scraper

import (
	"regexp"
	"strings"
)

func parseChannelsFromJS(html string) map[string]string {
	channels := make(map[string]string)
	patterns := []string{
		`(?:const|var|let)\s+channels\s*=\s*\{([^}]+)\}`,
		`channels\s*=\s*\{([^}]+)\}`,
		`channels\s*:\s*\{([^}]+)\}`,
	}

	var body string
	for _, pat := range patterns {
		re := regexp.MustCompile(pat)
		matches := re.FindStringSubmatch(html)
		if len(matches) > 1 {
			body = matches[1]
			break
		}
	}

	if body == "" {
		return channels
	}

	pairRe := regexp.MustCompile(`['"](\w[^'"]*)['"]\s*:\s*['"]((?:https?://[^'"]+)|(?:/[^'"]+))['"]`)
	pairs := pairRe.FindAllStringSubmatch(body, -1)

	for _, pair := range pairs {
		if len(pair) > 2 {
			name := strings.TrimSpace(pair[1])
			link := strings.TrimSpace(pair[2])

			if !strings.HasPrefix(link, "http") && strings.HasPrefix(link, "//") {
				link = "https:" + link
			}

			if strings.HasPrefix(link, "/") {
				link = BaseURL + link
			}

			link = strings.ReplaceAll(link, "streamtp-x-y-z.ws", "streamtpday1.xyz")
			channels[name] = link
		}
	}

	return channels
}
