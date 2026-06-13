package scraper

import "strings"

func fetchEventosJSON() ([]Event, error) {
	var raw []eventoRaw
	err := fetchJSON(EventosJSON, &raw)
	if err != nil {
		return nil, err
	}

	var events []Event
	for i, e := range raw {
		ev := Event{
			ID:       "ev_" + string(i+1),
			Title:    e.Title,
			Category: e.Category,
			Date:     e.Date,
			Time:     e.Time,
			Language: e.Language,
			Quality:  "HD",
			AdFree:   isAdFree(e.Link),
		}

		if e.Link != "" {
			if strings.Contains(e.Link, ".m3u8") {
				ev.StreamURL = e.Link
			} else {
				ev.EmbedURL = e.Link
			}
		}

		switch strings.ToLower(e.Status) {
		case "en vivo", "live", "activo":
			ev.IsLive = true
			ev.IsActive = true
		case "pronto", "next":
			ev.IsLive = false
			ev.IsActive = true
		default:
			ev.IsLive = false
			ev.IsActive = false
		}

		if ev.Language == "" || ev.Language == "Other" {
			ev.Language = inferLanguage(e.Link)
		}
		if ev.Category == "" {
			ev.Category = "Deportes"
		}

		events = append(events, ev)
	}

	groupEventsByTitle(events)
	return events, nil
}

func groupEventsByTitle(events []Event) {
	groups := make(map[string][]int)
	for i, ev := range events {
		key := normalizeTitle(ev.Title)
		groups[key] = append(groups[key], i)
	}

	for _, indices := range groups {
		if len(indices) <= 1 {
			continue
		}
		var allURLs []string
		for _, idx := range indices {
			url := events[idx].playURL()
			if url != "" {
				allURLs = append(allURLs, url)
			}
		}
		for _, idx := range indices {
			var others []string
			for _, u := range allURLs {
				if u != events[idx].playURL() {
					others = append(others, u)
				}
			}
			if len(others) > 0 {
				events[idx].FallbackURLs = others
			}
		}
	}
}
