package scraper

import (
	"strings"
)

func inferLanguage(link string) string {
	lower := strings.ToLower(link)

	mxKeywords := []string{ "tudnmx", "canalfive", "azteca", "espnmx", "foxsportsmx", "tudn", "univision", "universo_usa", "fox_deportes", "canal5mx", "telemundo" }
	arKeywords := []string{ "tycsports", "tntsports", "telefe", "tv_publica", "fox1ar", "fox2ar", "espnpremium", "dsports", "winsports", "winplus" }
	brKeywords := []string{ "premiere", "sporttvbr", "espnbr", "globosat" }
	enKeywords := []string{ "tsn", "tnt_", "fox_1_usa", "fox_2_usa", "usa_network", "espn_nl" }
	peKeywords := []string{ "liga1max", "futv", "golperu" }
	coKeywords := []string{ "caracoltv", "rcnmundo" }

	checkKeywords := func(keywords []string) bool {
		for _, kw := range keywords {
			if strings.Contains(lower, kw) {
				return true
			}
		}
		return false
	}

	if checkKeywords(mxKeywords) {
		return "ES-MX"
	}
	if checkKeywords(arKeywords) {
		return "ES-AR"
	}
	if checkKeywords(brKeywords) {
		return "PT-BR"
	}
	if checkKeywords(enKeywords) {
		return "EN"
	}
	if checkKeywords(peKeywords) {
		return "ES-PE"
	}
	if checkKeywords(coKeywords) {
		return "ES-CO"
	}
	return "ES"
}
