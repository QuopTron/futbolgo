package scraper

func ResolveStreamFromURL(proxyURL string) string {
	if IsUnresolvableURL(proxyURL) {
		return buildResolveResponse(false, "", proxyURL, "URL no soportada: contenidos con anti-framekill (sudamericaplay2)")
	}

	m3u8URL, err := ResolveStreamURL(proxyURL)
	if err != nil {
		return buildResolveResponse(false, "", proxyURL, err.Error())
	}

	return buildResolveResponse(true, m3u8URL, proxyURL, "")
}
