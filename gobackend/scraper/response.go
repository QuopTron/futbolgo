package scraper

import "encoding/json"

func buildResolveResponse(resolved bool, m3u8URL, originalURL, errorMsg string) string {
	resp := map[string]interface{}{
		"resolved": resolved,
		"original": originalURL,
	}
	if resolved {
		resp["m3u8_url"] = m3u8URL
		resp["safe"] = !IsAdDomain(m3u8URL) && !IsAdContent(m3u8URL)
	} else {
		resp["error"] = errorMsg
	}
	b, _ := json.Marshal(resp)
	return string(b)
}
