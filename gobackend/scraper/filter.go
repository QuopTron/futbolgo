package scraper

import "encoding/json"

func FilterAdStreams(dataJSON string) string {
	var input struct {
		Events   json.RawMessage `json:"events"`
		Channels json.RawMessage `json:"channels"`
	}
	if err := json.Unmarshal([]byte(dataJSON), &input); err != nil {
		return dataJSON
	}

	if input.Events != nil {
		var allEvents []Event
		json.Unmarshal(input.Events, &allEvents)
		filtered := make([]Event, 0)
		for _, e := range allEvents {
			if isAdFree(e.StreamURL) && isAdFree(e.EmbedURL) {
				e.AdFree = true
				filtered = append(filtered, e)
			} else if e.StreamURL != "" || e.EmbedURL != "" {
				e.AdFree = false
				filtered = append(filtered, e)
			}
		}
		input.Events, _ = json.Marshal(filtered)
	}

	if input.Channels != nil {
		var allChannels []Channel
		json.Unmarshal(input.Channels, &allChannels)
		filtered := make([]Channel, 0)
		for _, ch := range allChannels {
			if isAdFree(ch.StreamURL) && isAdFree(ch.EmbedURL) {
				ch.AdFree = true
				filtered = append(filtered, ch)
			} else if ch.StreamURL != "" || ch.EmbedURL != "" {
				ch.AdFree = false
				filtered = append(filtered, ch)
			}
		}
		input.Channels, _ = json.Marshal(filtered)
	}

	r := struct {
		Events   json.RawMessage `json:"events"`
		Channels json.RawMessage `json:"channels"`
	}{
		Events:   input.Events,
		Channels: input.Channels,
	}

	b, _ := json.Marshal(r)
	return string(b)
}
