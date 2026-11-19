import Foundation

enum DemoCatalog {
    static let sintel = "demo.sintel"
    static let credit = "وسائط العرض التجريبي أفلام مفتوحة من مؤسسة بلندر (سينتل، الأرنب الكبير، دموع الفولاذ، حلم الفيلة) برخصة نَسب المُصنَّف، إضافة إلى أمثلة Apple وMux للبث التجريبي."

    static func make(now: Date = .now) -> Catalog {
        Catalog(
            movies: movies(),
            series: [sintelSeries(), moonSeries()],
            channels: channels(now: now),
            clips: clips()
        )
    }

    static func movies() -> [MediaItem] {
        [
            movie(
                id: "demo.steel",
                title: "دموع الفولاذ",
                overview: "في مدينة ممطرة، يواجه آخر الناجين آلة لا تنام.",
                year: 2024,
                rating: "PG",
                genres: ["دراما", "خيال"],
                poster: "PosterSteel",
                stream: PublicStreams.steel,
                minutes: 12,
                category: "دراما"
            ),
            movie(
                id: "demo.rabbit",
                title: "الأرنب الكبير",
                overview: "مغامرة عائلية في مرج مشمس، عن يوم لا يسير كما خُطّط له.",
                year: 2024,
                rating: "G",
                genres: ["عائلي", "كوميديا"],
                poster: "PosterRabbit",
                stream: PublicStreams.bunny,
                minutes: 10,
                category: "عائلي"
            ),
            movie(
                id: "demo.dream",
                title: "حلم الفيلة",
                overview: "صحراء بنفسجية تمشي فيها كائنات هادئة تحت قمر واسع.",
                year: 2023,
                rating: "PG",
                genres: ["خيال", "غموض"],
                poster: "PosterDream",
                stream: PublicStreams.elephants,
                minutes: 11,
                category: "خيال"
            ),
            movie(
                id: "demo.gate",
                title: "بوابة الرماد",
                overview: "بوابة قديمة تُفتح مرة كل جيل، ومن يعبرها لا يعود كما كان.",
                year: 2022,
                rating: "18+",
                genres: ["إثارة", "خيال"],
                poster: "PosterGate",
                stream: PublicStreams.steel,
                minutes: 12,
                category: "إثارة"
            ),
            movie(
                id: "demo.forest",
                title: "غابة الضوء",
                overview: "ضوء صغير يضيء طريقاً بين أشجار لا تنام.",
                year: 2024,
                rating: "PG",
                genres: ["خيال", "مغامرة"],
                poster: "ThumbForest",
                stream: PublicStreams.sintel,
                minutes: 15,
                category: "خيال"
            ),
            movie(
                id: "demo.airship",
                title: "أساطيل الغيم",
                overview: "مدن عائمة وسفن نحاسية تسابق الغروب.",
                year: 2024,
                rating: "PG",
                genres: ["مغامرة", "خيال"],
                poster: "ThumbAirship",
                stream: PublicStreams.bunny,
                minutes: 10,
                category: "مغامرة"
            ),
            movie(
                id: "demo.ocean",
                title: "أعماق ليل",
                overview: "سلاحف تعبر أعمدة الضوء في بحر لا نهاية له.",
                year: 2024,
                rating: "G",
                genres: ["وثائقي", "طبيعة"],
                poster: "ThumbOcean",
                stream: PublicStreams.elephants,
                minutes: 11,
                category: "وثائقي"
            )
        ]
    }

    static func sintelSeries() -> SeriesDetail {
        let item = MediaItem(
            id: sintel,
            kind: .series,
            title: "سينتل",
            overview: "فتاة شجاعة تكتشف عالماً سحرياً.",
            year: 2024,
            rating: "PG",
            quality: "HD",
            genres: ["خيال", "مغامرة", "أكشن"],
            posterAsset: "PosterSintel",
            posterURL: nil,
            backdropAsset: "BackdropSintel",
            backdropURL: nil,
            streamURL: PublicStreams.sintel,
            durationMinutes: 25,
            category: "خيال",
            playlistID: nil,
            isDemo: true,
            credit: credit
        )
        let episodes = [
            Episode(id: "demo.sintel.s1e1", number: 1, seasonNumber: 1, title: "البداية", overview: "تبدأ الرحلة عند حافة الجبل.", durationMinutes: 25, stillAsset: "EpisodeBegin", stillURL: nil, streamURL: PublicStreams.sintel),
            Episode(id: "demo.sintel.s1e2", number: 2, seasonNumber: 1, title: "الرحلة", overview: "طريق طويل فوق السحب.", durationMinutes: 23, stillAsset: "EpisodeJourney", stillURL: nil, streamURL: PublicStreams.steel),
            Episode(id: "demo.sintel.s1e3", number: 3, seasonNumber: 1, title: "المواجهة", overview: "العاصفة تبلغ القلعة.", durationMinutes: 27, stillAsset: "EpisodeFace", stillURL: nil, streamURL: PublicStreams.bunny)
        ]
        let season = Season(id: "demo.sintel.s1", number: 1, title: "الموسم 1", episodes: episodes)
        return SeriesDetail(id: item.id, item: item, seasons: [season])
    }

    static func moonSeries() -> SeriesDetail {
        let item = MediaItem(
            id: "demo.moon",
            kind: .series,
            title: "حكايات القمر",
            overview: "قافلة ليلية تتبع قمراً لا يغرب.",
            year: 2024,
            rating: "PG",
            quality: "HD",
            genres: ["دراما", "خيال"],
            posterAsset: "PosterMoon",
            posterURL: nil,
            backdropAsset: "PosterMoon",
            backdropURL: nil,
            streamURL: PublicStreams.elephants,
            durationMinutes: 22,
            category: "دراما",
            playlistID: nil,
            isDemo: true,
            credit: credit
        )
        let season1 = Season(
            id: "demo.moon.s1",
            number: 1,
            title: "الموسم 1",
            episodes: [
                Episode(id: "demo.moon.s1e1", number: 1, seasonNumber: 1, title: "القافلة", overview: "", durationMinutes: 22, stillAsset: "EpisodeJourney", stillURL: nil, streamURL: PublicStreams.elephants),
                Episode(id: "demo.moon.s1e2", number: 2, seasonNumber: 1, title: "البئر", overview: "", durationMinutes: 24, stillAsset: "ThumbOcean", stillURL: nil, streamURL: PublicStreams.sintel)
            ]
        )
        let season2 = Season(
            id: "demo.moon.s2",
            number: 2,
            title: "الموسم 2",
            episodes: [
                Episode(id: "demo.moon.s2e1", number: 1, seasonNumber: 2, title: "الوعد", overview: "", durationMinutes: 26, stillAsset: "PosterMoon", stillURL: nil, streamURL: PublicStreams.steel)
            ]
        )
        return SeriesDetail(id: item.id, item: item, seasons: [season1, season2])
    }

    static func channels(now: Date) -> [LiveChannel] {
        [
            channel(id: "demo.ch.cinema", name: "ليل سينما", number: 1, category: "سينما", stream: PublicStreams.appleAdvanced, symbol: "film", titles: ["افتتاح السهرة", "فيلم الليلة", "حوار بعد العرض", "إعادة مختارة"], now: now),
            channel(id: "demo.ch.drama", name: "ليل دراما", number: 2, category: "دراما", stream: PublicStreams.steelHLS, symbol: "theatermasks", titles: ["الفصل الأول", "استراحة", "الفصل الأخير", "خلف الكواليس"], now: now),
            channel(id: "demo.ch.kids", name: "ليل أطفال", number: 3, category: "أطفال", stream: PublicStreams.muxBunny, symbol: "figure.and.child.holdinghands", titles: ["صباح الرسوم", "قصة قبل النوم", "أغنية قصيرة", "مغامرة المرج"], now: now),
            channel(id: "demo.ch.docs", name: "ليل وثائقيات", number: 4, category: "وثائقي", stream: PublicStreams.appleBipBop, symbol: "globe.europe.africa", titles: ["كوكب قريب", "أصوات المحيط", "مدن قديمة", "سماء الليل"], now: now),
            channel(id: "demo.ch.news", name: "ليل أخبار", number: 5, category: "أخبار", stream: PublicStreams.appleAdvanced, symbol: "newspaper", titles: ["موجز", "تقرير خاص", "الطقس", "خاتمة اليوم"], now: now),
            channel(id: "demo.ch.sport", name: "ليل رياضة", number: 6, category: "رياضة", stream: PublicStreams.appleBipBop, symbol: "sportscourt", titles: ["استوديو المباراة", "الشوط الأول", "التحليل", "أهداف اليوم"], now: now)
        ]
    }

    static func clips() -> [ClipItem] {
        [
            ClipItem(id: "demo.clip.ember", title: "جمر الحارة", creator: "ليل", overview: "خطوات أخيرة قبل إغلاق الأبواب.", posterAsset: "ClipEmber", streamURL: PublicStreams.sintel, isDemo: true),
            ClipItem(id: "demo.clip.tide", title: "مدّ القمر", creator: "ليل", overview: "موجة واحدة تكفي لتغيير الاتجاه.", posterAsset: "ClipTide", streamURL: PublicStreams.bunny, isDemo: true),
            ClipItem(id: "demo.clip.drift", title: "فانوس الرمل", creator: "ليل", overview: "قافلة صغيرة وضوء لا ينطفئ.", posterAsset: "ClipDrift", streamURL: PublicStreams.elephants, isDemo: true),
            ClipItem(id: "demo.clip.spark", title: "شرارة", creator: "ليل", overview: "حدّاد يعمل والمدينة نائمة.", posterAsset: "ClipSpark", streamURL: PublicStreams.steel, isDemo: true)
        ]
    }

    static let exclusiveIDs = ["demo.forest", "demo.airship", "demo.ocean"]

    private static func movie(
        id: String,
        title: String,
        overview: String,
        year: Int,
        rating: String,
        genres: [String],
        poster: String,
        stream: String,
        minutes: Int,
        category: String
    ) -> MediaItem {
        MediaItem(
            id: id,
            kind: .movie,
            title: title,
            overview: overview,
            year: year,
            rating: rating,
            quality: "HD",
            genres: genres,
            posterAsset: poster,
            posterURL: nil,
            backdropAsset: poster,
            backdropURL: nil,
            streamURL: stream,
            durationMinutes: minutes,
            category: category,
            playlistID: nil,
            isDemo: true,
            credit: credit
        )
    }

    private static func channel(
        id: String,
        name: String,
        number: Int,
        category: String,
        stream: String,
        symbol: String,
        titles: [String],
        now: Date
    ) -> LiveChannel {
        LiveChannel(
            id: id,
            name: name,
            number: number,
            category: category,
            logoAsset: "symbol:\(symbol)",
            logoURL: nil,
            streamURL: stream,
            epgID: id,
            programs: programs(channelID: id, titles: titles, now: now),
            playlistID: nil,
            isDemo: true
        )
    }

    static func programs(channelID: String, titles: [String], now: Date) -> [EPGProgram] {
        let slot: TimeInterval = 60 * 60
        let origin = now.addingTimeInterval(-slot)
        return titles.enumerated().map { index, title in
            let start = origin.addingTimeInterval(Double(index) * slot)
            return EPGProgram(
                id: "\(channelID)-\(index)",
                title: title,
                start: start,
                end: start.addingTimeInterval(slot),
                overview: "دليل برامج تجريبي يتحرك مع الوقت حتى يبقى هناك برنامج على الهواء."
            )
        }
    }
}
