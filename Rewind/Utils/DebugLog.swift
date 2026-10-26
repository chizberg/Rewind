//
//  DebugLog.swift
//  Rewind
//
//  Debug builds write to the unified log, Settings → Debug → Export logs dumps the app's
//  entries from the current launch to a file. Release builds compile it away.
//

import OSLog

func debugLog(_ message: @autoclosure () -> String) {
  #if DEBUG
  let message = message()
  logger.notice("\(message, privacy: .public)")
  #endif
}

// like "\(value)", but collections are replaced with their counts
// and long descriptions are cut to keep log entries short
func debugSummary(_ value: Any) -> String {
  let mirror = Mirror(reflecting: value)
  let hasDescription = value is CustomStringConvertible
  switch mirror.displayStyle {
  case .collection, .set, .dictionary:
    return "\((value as? any Collection)?.count ?? mirror.children.count) items"
  case .optional:
    return mirror.children.first.map { debugSummary($0.value) } ?? "nil"
  case .enum where !hasDescription:
    guard let payload = mirror.children.first else { return "\(value)" }
    let isTuple = Mirror(reflecting: payload.value).displayStyle == .tuple
    let summary = debugSummary(payload.value)
    return "\(payload.label ?? "")\(isTuple ? summary : "(\(summary))")"
  case .struct where !hasDescription && !mirror.children.isEmpty, .tuple:
    let fields = mirror.children.map { child in
      let label = child.label.flatMap { $0.hasPrefix(".") ? nil : "\($0): " } ?? ""
      return label + debugSummary(child.value)
    }
    return "(\(fields.joined(separator: ", ")))"
  default:
    let description = "\(value)"
    return description.count > 100 ? description.prefix(100) + "…" : description
  }
}

#if DEBUG
func exportDebugLogs() throws -> URL {
  let store = try OSLogStore(scope: .currentProcessIdentifier)
  let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current)
  let text = try store.getEntries(matching: NSPredicate(format: "subsystem == %@", subsystem))
    .compactMap { $0 as? OSLogEntryLog }
    .map { "\($0.date.formatted(dateStyle)) \($0.composedMessage)" }
    .joined(separator: "\n")
  let url = FileManager.default.temporaryDirectory.appending(path: "Rewind-logs.txt")
  try text.write(to: url, atomically: true, encoding: .utf8)
  return url
}

private let subsystem = "chizberg.Rewind"
private let logger = Logger(subsystem: subsystem, category: "debug")
#endif
