package scraper

import (
	"crypto/md5"
	"strings"
	"unicode"
)

func normalizeTitle(title string) string {
	r := strings.NewReplacer(
		"á", "a", "é", "e", "í", "i", "ó", "o", "ú", "u",
		"Á", "A", "É", "E", "Í", "I", "Ó", "O", "Ú", "U",
		"ñ", "n", "Ñ", "N",
		"ü", "u", "Ü", "U",
	)
	noAccents := r.Replace(title)
	noPunc := strings.Map(func(r rune) rune {
		if unicode.IsPunct(r) || unicode.IsSymbol(r) {
			return -1
		}
		return r
	}, noAccents)
	return strings.TrimSpace(strings.ToLower(noPunc))
}

func titleHash(title string) string {
	h := md5.New()
	h.Write([]byte(normalizeTitle(title)))
	return string(h.Sum(nil)[:8])
}
