import Foundation
import Testing
@testable import Halfway

struct LastFMTests {
  @Test
  func signatureSortsParametersAndSkipsFormat() {
    let params = ["method": "auth.getToken", "api_key": "k", "format": "json"]
    // md5("api_keykmethodauth.getTokens")
    #expect(LastFMClient.signature(params, secret: "s") == "fcb68e4c03131d77e8851e889687a441")
  }

  @Test
  func formBodyEscapesReservedCharacters() {
    let body = String(bytes: LastFMClient.formBody(["artist[0]": "AC/DC & Friends+1"]), encoding: .utf8)
    #expect(body == "artist%5B0%5D=AC%2FDC%20%26%20Friends%2B1")
  }

  @Test
  func parsesMusicNotification() {
    let info: [AnyHashable: Any] = [
      "Player State": "Playing",
      "Name": "Song",
      "Artist": "Artist",
      "Album": "Album",
      "Total Time": NSNumber(value: 215_000),
      "PersistentID": NSNumber(value: Int64(-1_234_567)),
    ]
    let snapshot = MusicObserver.parse(info)
    #expect(snapshot.state == .playing)
    #expect(snapshot.track?.duration == 215)
    #expect(snapshot.track?.id == "-1234567")
    #expect(snapshot.track?.albumArtist == nil)
  }

  @Test
  func readsOutcomesForSeveralScrobbles() throws {
    let json: [String: Any] = [
      "scrobbles": [
        "scrobble": [
          ["ignoredMessage": ["code": "0", "#text": ""]],
          ["ignoredMessage": ["code": "3", "#text": "Timestamp too old"]],
        ],
        "@attr": ["accepted": 1, "ignored": 1],
      ]
    ]
    #expect(try LastFMClient.outcomes(from: json, count: 2) == [.accepted, .ignored("Timestamp too old")])
  }

  @Test
  func readsOutcomeForOneScrobble() throws {
    let json: [String: Any] = [
      "scrobbles": ["scrobble": ["ignoredMessage": ["code": "0", "#text": ""]], "@attr": ["accepted": 1]]
    ]
    #expect(try LastFMClient.outcomes(from: json, count: 1) == [.accepted])
  }

  @Test
  func unmatchedOutcomesCountAsSentToAvoidDuplicates() throws {
    let json: [String: Any] = ["scrobbles": ["@attr": ["accepted": 2, "ignored": 0]]]
    #expect(try LastFMClient.outcomes(from: json, count: 2) == [.accepted, .accepted])
  }
}
