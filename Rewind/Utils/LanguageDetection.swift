//
//  LanguageDetection.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 17. 2. 2026..
//

import NaturalLanguage

struct DetectedLanguage {
  var languageCode: String
  var confidence: Double
}

func detectLanguage(_ text: String) -> DetectedLanguage? {
  let recognizer = NLLanguageRecognizer()
  recognizer.processString(text)
  guard let lang = recognizer.dominantLanguage,
        let confidence = recognizer.languageHypotheses(withMaximum: 1)[lang]
  else {
    assertionFailure("unable to detect language")
    return nil
  }
  return DetectedLanguage(languageCode: lang.rawValue, confidence: confidence)
}
