package scraper

import (
	"strings"
)

var channelFallbacks = map[string]struct {
	Fallbacks []string
	Language  string
}{
	"espn":           {Fallbacks: []string{"espn2", "espn3"}, Language: "ES"},
	"espn2":          {Fallbacks: []string{"espn", "espn3"}, Language: "ES"},
	"espn3":          {Fallbacks: []string{"espn", "espn2"}, Language: "ES"},
	"tntsports":      {Fallbacks: []string{"tntsportschile", "tnt_1_gb"}, Language: "ES"},
	"tntsportschile": {Fallbacks: []string{"tntsports", "tnt_1_gb"}, Language: "ES"},
	"winsports":      {Fallbacks: []string{"winplus", "winplus2"}, Language: "ES"},
	"winplus":        {Fallbacks: []string{"winsports", "winplus2"}, Language: "ES"},
	"winplus2":       {Fallbacks: []string{"winsports", "winplus"}, Language: "ES"},
	"dsports":        {Fallbacks: []string{"dsports2", "dsportsplus"}, Language: "ES"},
	"dsports2":       {Fallbacks: []string{"dsports", "dsportsplus"}, Language: "ES"},
	"dsportsplus":    {Fallbacks: []string{"dsports", "dsports2"}, Language: "ES"},
	"fox1ar":         {Fallbacks: []string{"fox2ar", "fox3ar"}, Language: "ES"},
	"fox2ar":         {Fallbacks: []string{"fox1ar", "fox3ar"}, Language: "ES"},
	"tycsports":      {Fallbacks: []string{"tycinternacional"}, Language: "ES"},
	"tycinternacional": {Fallbacks: []string{"tycsports"}, Language: "ES"},
	"premiere1":      {Fallbacks: []string{"premiere2", "premiere3"}, Language: "PT"},
	"premiere2":      {Fallbacks: []string{"premiere1", "premiere3"}, Language: "PT"},
	"premiere3":      {Fallbacks: []string{"premiere1", "premiere2"}, Language: "PT"},
	"sporttvbr1":     {Fallbacks: []string{"sporttvbr2", "sporttvbr3"}, Language: "PT"},
	"sporttvbr2":     {Fallbacks: []string{"sporttvbr1", "sporttvbr3"}, Language: "PT"},
	"sporttvbr3":     {Fallbacks: []string{"sporttvbr1", "sporttvbr2"}, Language: "PT"},
	"espnmx":         {Fallbacks: []string{"espn2mx", "espn3mx"}, Language: "ES"},
	"foxsportsmx":    {Fallbacks: []string{"foxsports2mx", "foxsports3mx"}, Language: "ES"},
	"fox_1_usa":      {Fallbacks: []string{"fox_2_usa", "fox_deportes_usa"}, Language: "EN"},
	"fox_2_usa":      {Fallbacks: []string{"fox_1_usa", "fox_deportes_usa"}, Language: "EN"},
	"tnt_1_gb":       {Fallbacks: []string{"tnt_2_gb", "tnt_3_gb"}, Language: "EN"},
	"tnt_2_gb":       {Fallbacks: []string{"tnt_1_gb", "tnt_3_gb"}, Language: "EN"},
	"tnt_3_gb":       {Fallbacks: []string{"tnt_1_gb", "tnt_2_gb"}, Language: "EN"},
}

func buildFallbackURLs(streamID string) []string {
	fallbacks, ok := channelFallbacks[streamID]
	if !ok {
		return nil
	}
	urls := make([]string, 0, len(fallbacks.Fallbacks))
	for _, fb := range fallbacks.Fallbacks {
		u := BaseURL + "/global1.php?stream=" + fb
		urls = append(urls, u)
	}
	return urls
}

func getChannelLanguage(streamID string) string {
	if fbInfo, ok := channelFallbacks[streamID]; ok {
		return fbInfo.Language
	}
	return "ES"
}

func IsUnresolvableURL(urlStr string) bool {
	lower := strings.ToLower(urlStr)
	return strings.Contains(lower, "sudamericaplay") || 
		strings.Contains(lower, "histats")
}
