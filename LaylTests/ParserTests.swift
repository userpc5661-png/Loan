import XCTest
@testable import Layl

final class ParserTests: XCTestCase {
    func testM3UAttributesAndArabicName() {
        let line = #"#EXTINF:-1 tvg-id="layl.cinema" tvg-name="ليل سينما" group-title="سينما",ليل سينما"#
        let attributes = M3UParser.attributes(in: line)
        XCTAssertEqual(attributes["tvg-id"], "layl.cinema")
        XCTAssertEqual(attributes["group-title"], "سينما")
        XCTAssertEqual(M3UParser.displayName(from: line), "ليل سينما")
    }

    func testCommaInsideQuotesDoesNotSplitName() {
        let line = #"#EXTINF:-1 group-title="أخبار, عاجلة",القناة الأولى"#
        XCTAssertEqual(M3UParser.attributes(in: line)["group-title"], "أخبار, عاجلة")
        XCTAssertEqual(M3UParser.displayName(from: line), "القناة الأولى")
    }

    func testClassifiesMoviesSeriesAndLive() throws {
        let text = """
        #EXTM3U
        #EXTINF:-1 group-title="سينما",ليل سينما
        https://example.com/live/master.m3u8
        #EXTINF:-1 group-title="أفلام",سينتل
        https://example.com/video/sintel.mp4
        #EXTINF:-1 group-title="مسلسلات",حكاية الليل S01E01
        https://example.com/ep1.mp4
        #EXTINF:-1 group-title="مسلسلات",حكاية الليل S01E02
        https://example.com/ep2.mp4
        """
        let parsed = M3UParser.parse(text, playlistID: UUID())
        XCTAssertEqual(parsed.catalog.channels.count, 1)
        XCTAssertEqual(parsed.catalog.channels.first?.name, "ليل سينما")
        XCTAssertEqual(parsed.catalog.movies.count, 1)
        XCTAssertEqual(parsed.catalog.movies.first?.title, "سينتل")
        XCTAssertEqual(parsed.catalog.series.count, 1)
        let series = try XCTUnwrap(parsed.catalog.series.first)
        XCTAssertEqual(series.item.title, "حكاية الليل")
        XCTAssertEqual(series.seasons.first?.episodes.count, 2)
        XCTAssertEqual(series.seasons.first?.episodes.first?.number, 1)
    }

    func testXMLTVDatesAndProgrammes() {
        let raw = "20241119120000 +0000"
        let date = XMLTVParser.parseDate(raw)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date!)
        XCTAssertEqual(parts.year, 2024)
        XCTAssertEqual(parts.month, 11)
        XCTAssertEqual(parts.day, 19)
        XCTAssertEqual(parts.hour, 12)

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme start="20241119120000 +0000" stop="20241119130000 +0000" channel="layl.cinema">
            <title>فيلم الليلة</title>
            <desc>عرض تجريبي</desc>
          </programme>
        </tv>
        """.data(using: .utf8)!
        let programs = XMLTVParser.parse(xml)
        XCTAssertEqual(programs["layl.cinema"]?.first?.title, "فيلم الليلة")
        XCTAssertEqual(programs["layl.cinema"]?.first?.overview, "عرض تجريبي")
    }

    func testFlexStringDecodesIntAndString() throws {
        let intJSON = "1".data(using: .utf8)!
        let stringJSON = "\"42\"".data(using: .utf8)!
        let asInt = try JSONDecoder().decode(FlexString.self, from: intJSON)
        let asString = try JSONDecoder().decode(FlexString.self, from: stringJSON)
        XCTAssertEqual(asInt.value, "1")
        XCTAssertEqual(asString.value, "42")
    }

    func testXtreamStreamURL() throws {
        let config = try XCTUnwrap(XtreamConfig.make(server: "http://example.com:8080/", username: "user", password: "secret"))
        let live = try XCTUnwrap(config.streamURL(kind: "live", id: "15", ext: "m3u8"))
        XCTAssertEqual(live.absoluteString, "http://example.com:8080/live/user/secret/15.m3u8")
        let api = try XCTUnwrap(config.apiURL(action: "get_live_categories"))
        XCTAssertTrue(api.absoluteString.contains("player_api.php"))
        XCTAssertTrue(api.absoluteString.contains("action=get_live_categories"))
    }

    func testBase64EPGTitle() {
        let encoded = Data("فيلم الليلة".utf8).base64EncodedString()
        XCTAssertEqual(MediaText.decodeMaybeBase64(encoded), "فيلم الليلة")
        XCTAssertEqual(MediaText.decodeMaybeBase64("أخبار"), "أخبار")
        XCTAssertEqual(MediaText.minutes(from: "01:25:00"), 85)
        XCTAssertEqual(MediaText.year(from: "2024-03-01"), 2024)
    }

    func testDemoHeroMatchesReference() throws {
        let catalog = DemoCatalog.make(now: Date(timeIntervalSince1970: 1_763_596_800))
        let series = try XCTUnwrap(catalog.seriesDetail(id: DemoCatalog.sintel))
        XCTAssertEqual(series.item.title, "سينتل")
        XCTAssertEqual(series.item.year, 2024)
        XCTAssertEqual(series.item.rating, "PG")
        XCTAssertEqual(series.item.quality, "HD")
        XCTAssertEqual(series.item.genres, ["خيال", "مغامرة", "أكشن"])
        XCTAssertEqual(series.item.overview, "فتاة شجاعة تكتشف عالماً سحرياً.")
        let episodes = try XCTUnwrap(series.seasons.first?.episodes)
        XCTAssertEqual(episodes.map(\.title), ["البداية", "الرحلة", "المواجهة"])
        XCTAssertEqual(episodes.map(\.durationMinutes), [25, 23, 27])
        XCTAssertEqual(DemoCatalog.exclusiveIDs.count, 3)
        let current = catalog.channels.first?.currentProgram(at: Date(timeIntervalSince1970: 1_763_596_800))
        XCTAssertNotNil(current)
    }

    func testKidsFilterHidesMatureTitles() {
        let filtered = DemoCatalog.make().kidsFiltered()
        XCTAssertFalse(filtered.movies.contains { $0.rating == "18+" })
        XCTAssertTrue(filtered.movies.contains { $0.id == "demo.rabbit" })
        XCTAssertFalse(filtered.channels.contains { $0.category == "رياضة" })
    }
}
