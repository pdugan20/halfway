#!/usr/bin/env swift
import CryptoKit
import Foundation

// Verify against the public key in the actual exported app, never the signing secret.
struct VerificationFailure: Error, CustomStringConvertible {
  let description: String
}

func require(_ condition: Bool, _ message: String) throws {
  if !condition { throw VerificationFailure(description: message) }
}

final class FeedParser: NSObject, XMLParserDelegate {
  var fields: [String: String] = [:]
  var enclosure: [String: String] = [:]
  var items = 0
  private var text = ""

  func parser(
    _: XMLParser, didStartElement elementName: String, namespaceURI _: String?,
    qualifiedName _: String?, attributes attributeDict: [String: String]
  ) {
    text = ""
    if elementName == "item" { items += 1 }
    if elementName == "enclosure" { enclosure = attributeDict }
  }

  func parser(_: XMLParser, foundCharacters string: String) { text += string }

  func parser(
    _: XMLParser, didEndElement elementName: String, namespaceURI _: String?, qualifiedName _: String?
  ) {
    fields[elementName] = text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

func verify() throws {
  let args = CommandLine.arguments
  try require(args.count == 6, "Usage: verify-update-feed.swift FEED DMG APP_INFO_PLIST TAG BUILD_NUMBER")
  let feed = try Data(contentsOf: URL(fileURLWithPath: args[1]))
  let archiveURL = URL(fileURLWithPath: args[2])
  let archive = try Data(contentsOf: archiveURL, options: .mappedIfSafe)
  let infoData = try Data(contentsOf: URL(fileURLWithPath: args[3]))
  guard
    let info = try PropertyListSerialization.propertyList(from: infoData, format: nil) as? [String: Any],
    let publicKeyString = info["SUPublicEDKey"] as? String,
    let keyData = Data(base64Encoded: publicKeyString)
  else { throw VerificationFailure(description: "App is missing its update public key") }
  let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)

  let marker = Data("<!-- sparkle-signatures:\n".utf8)
  guard
    let markerRange = feed.range(of: marker),
    let trailer = String(data: feed[markerRange.lowerBound...], encoding: .utf8)
  else { throw VerificationFailure(description: "Feed has no signature trailer") }
  let pattern = #"^<!-- sparkle-signatures:\nedSignature: ([A-Za-z0-9+/=]+)\nlength: ([0-9]+)\n-->\n?$"#
  let regex = try NSRegularExpression(pattern: pattern)
  guard
    let match = regex.firstMatch(in: trailer, range: NSRange(trailer.startIndex..., in: trailer)),
    let signatureRange = Range(match.range(at: 1), in: trailer),
    let lengthRange = Range(match.range(at: 2), in: trailer),
    let signature = Data(base64Encoded: String(trailer[signatureRange])),
    let length = Int(trailer[lengthRange])
  else { throw VerificationFailure(description: "Invalid feed signature trailer") }
  try require(length == markerRange.lowerBound, "Feed signed length does not match its content")
  let signedXML = feed.prefix(length)
  try require(key.isValidSignature(signature, for: signedXML), "Feed signature does not match the app's public key")

  let delegate = FeedParser()
  let parser = XMLParser(data: signedXML)
  parser.shouldResolveExternalEntities = false
  parser.delegate = delegate
  try require(parser.parse(), "Invalid appcast XML")
  try require(delegate.items == 1, "Expected a single full-update enclosure")
  let fields = delegate.fields
  let enclosure = delegate.enclosure
  let expectedURL = "https://github.com/pdugan20/halfway/releases/download/\(args[4])/\(archiveURL.lastPathComponent)"
  try require(enclosure["url"] == expectedURL, "Enclosure URL does not match this release")
  try require(enclosure["length"] == String(archive.count), "Archive byte count differs from the appcast")
  try require(fields["sparkle:version"] == args[5], "Appcast build number differs from this release")
  try require(info["CFBundleVersion"] as? String == args[5], "App build number differs from this release")
  let version = String(args[4].dropFirst())
  try require(fields["sparkle:shortVersionString"] == version, "Appcast version differs from the tag")
  try require(info["CFBundleShortVersionString"] as? String == version, "App version differs from the tag")
  try require(
    fields["sparkle:minimumSystemVersion"] == info["LSMinimumSystemVersion"] as? String,
    "Minimum OS differs from the app"
  )
  guard let archiveSignature = enclosure["sparkle:edSignature"].flatMap({ Data(base64Encoded: $0) }) else {
    throw VerificationFailure(description: "Missing archive signature")
  }
  try require(key.isValidSignature(archiveSignature, for: archive), "Archive signature does not match the app's public key")
  print("Update feed, archive signatures, versions and download URL verified")
}

do {
  try verify()
} catch {
  fputs("Update verification failed: \(error)\n", stderr)
  exit(1)
}
