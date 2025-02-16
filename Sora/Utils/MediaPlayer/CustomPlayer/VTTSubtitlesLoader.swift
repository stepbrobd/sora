//
//  VTTSubtitlesLoader.swift
//  Sora
//
//  Created by Francesco on 15/02/25.
//

import Combine
import Foundation

struct SubtitleCue: Identifiable {
    let id = UUID()
    let startTime: Double
    let endTime: Double
    let text: String
}

class VTTSubtitlesLoader: ObservableObject {
    @Published var cues: [SubtitleCue] = []
    
    func load(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.custom.dataTask(with: url) { data, _, error in
            guard let data = data,
                  let vttContent = String(data: data, encoding: .utf8),
                  error == nil else { return }
            DispatchQueue.main.async {
                self.cues = self.parseVTT(content: vttContent)
            }
        }.resume()
    }
    
    private func parseVTT(content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let lines = content.components(separatedBy: .newlines)
        var index = 0
        
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line == "WEBVTT" {
                index += 1
                continue
            }
            
            if !line.contains("-->") {
                index += 1
                if index >= lines.count { break }
            }
            
            let timeLine = lines[index]
            let times = timeLine.components(separatedBy: "-->")
            if times.count < 2 {
                index += 1
                continue
            }
            
            let startTime = parseTimecode(times[0].trimmingCharacters(in: .whitespaces))
            let adjustedStartTime = max(startTime - 0.5, 0)
            let endTime = parseTimecode(times[1].trimmingCharacters(in: .whitespaces))
            let adjusteEndTime = max(endTime - 0.5, 0)
            index += 1
            var cueText = ""
            while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                cueText += lines[index] + "\n"
                index += 1
            }
            cues.append(SubtitleCue(startTime: adjustedStartTime, endTime: adjusteEndTime, text: cueText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return cues
    }
    
    private func parseTimecode(_ timeString: String) -> Double {
        let parts = timeString.components(separatedBy: ":")
        var seconds = 0.0
        if parts.count == 3,
           let h = Double(parts[0]),
           let m = Double(parts[1]),
           let s = Double(parts[2].replacingOccurrences(of: ",", with: ".")) {
            seconds = h * 3600 + m * 60 + s
        } else if parts.count == 2,
                  let m = Double(parts[0]),
                  let s = Double(parts[1].replacingOccurrences(of: ",", with: ".")) {
            seconds = m * 60 + s
        }
        return seconds
    }
}
