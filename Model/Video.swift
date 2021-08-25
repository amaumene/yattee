import Alamofire
import AVKit
import Foundation
import SwiftyJSON

struct Video: Identifiable, Equatable {
    let id: String
    var title: String
    var thumbnails: [Thumbnail]
    var author: String
    var length: TimeInterval
    var published: String
    var views: Int
    var description: String
    var genre: String

    // index used when in the Playlist
    let indexID: String?

    var live: Bool
    var upcoming: Bool

    var streams = [Stream]()
    var hlsUrl: URL?

    var publishedAt: Date?
    var likes: Int?
    var dislikes: Int?
    var keywords = [String]()

    var channel: Channel

    init(
        id: String,
        title: String,
        author: String,
        length: TimeInterval,
        published: String,
        views: Int,
        description: String,
        genre: String,
        channel: Channel,
        thumbnails: [Thumbnail] = [],
        indexID: String? = nil,
        live: Bool = false,
        upcoming: Bool = false,
        publishedAt: Date? = nil,
        likes: Int? = nil,
        dislikes: Int? = nil,
        keywords: [String] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.length = length
        self.published = published
        self.views = views
        self.description = description
        self.genre = genre
        self.channel = channel
        self.thumbnails = thumbnails
        self.indexID = indexID
        self.live = live
        self.upcoming = upcoming
        self.publishedAt = publishedAt
        self.likes = likes
        self.dislikes = dislikes
        self.keywords = keywords
    }

    init(_ json: JSON) {
        let videoID = json["videoId"].stringValue

        if let id = json["indexId"].string {
            indexID = id
            self.id = videoID + id
        } else {
            indexID = nil
            id = videoID
        }

        title = json["title"].stringValue
        author = json["author"].stringValue
        length = json["lengthSeconds"].doubleValue
        published = json["publishedText"].stringValue
        views = json["viewCount"].intValue
        description = json["description"].stringValue
        genre = json["genre"].stringValue

        thumbnails = Video.extractThumbnails(from: json)

        live = json["liveNow"].boolValue
        upcoming = json["isUpcoming"].boolValue

        likes = json["likeCount"].int
        dislikes = json["dislikeCount"].int

        keywords = json["keywords"].arrayValue.map { $0.stringValue }

        if let publishedInterval = json["published"].double {
            publishedAt = Date(timeIntervalSince1970: publishedInterval)
        }

        streams = Video.extractFormatStreams(from: json["formatStreams"].arrayValue)
        streams.append(contentsOf: Video.extractAdaptiveFormats(from: json["adaptiveFormats"].arrayValue))

        hlsUrl = json["hlsUrl"].url
        channel = Channel(json: json)
    }

    var playTime: String? {
        guard !length.isZero else {
            return nil
        }

        let formatter = DateComponentsFormatter()

        formatter.unitsStyle = .positional
        formatter.allowedUnits = length >= (60 * 60) ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]

        return formatter.string(from: length)
    }

    var publishedDate: String? {
        (published.isEmpty || published == "0 seconds ago") ? nil : published
    }

    var viewsCount: String? {
        views != 0 ? formattedCount(views) : nil
    }

    var likesCount: String? {
        formattedCount(likes)
    }

    var dislikesCount: String? {
        formattedCount(dislikes)
    }

    func formattedCount(_ count: Int!) -> String? {
        guard count != nil else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1

        var number: NSNumber
        var unit: String

        if count < 1000 {
            return "\(count!)"
        } else if count < 1_000_000 {
            number = NSNumber(value: Double(count) / 1000.0)
            unit = "K"
        } else {
            number = NSNumber(value: Double(count) / 1_000_000.0)
            unit = "M"
        }

        return "\(formatter.string(from: number)!)\(unit)"
    }

    var selectableStreams: [Stream] {
        let streams = streams.sorted { $0.resolution > $1.resolution }
        var selectable = [Stream]()

        Stream.Resolution.allCases.forEach { resolution in
            if let stream = streams.filter({ $0.resolution == resolution }).min(by: { $0.kind < $1.kind }) {
                selectable.append(stream)
            }
        }

        return selectable
    }

    var defaultStream: Stream? {
        selectableStreams.first { $0.kind == .stream }
    }

    var bestStream: Stream? {
        selectableStreams.min { $0.resolution > $1.resolution }
    }

    func streamWithResolution(_ resolution: Stream.Resolution) -> Stream? {
        selectableStreams.first { $0.resolution == resolution }
    }

    func defaultStreamForProfile(_ profile: Profile) -> Stream? {
        streamWithResolution(profile.defaultStreamResolution.value) ?? streams.first
    }

    func thumbnailURL(quality: Thumbnail.Quality) -> URL? {
        thumbnails.first { $0.quality == quality }?.url
    }

    private static func extractThumbnails(from details: JSON) -> [Thumbnail] {
        details["videoThumbnails"].arrayValue.map { json in
            Thumbnail(json)
        }
    }

    private static func extractFormatStreams(from streams: [JSON]) -> [Stream] {
        streams.map {
            SingleAssetStream(
                avAsset: AVURLAsset(url: InvidiousAPI.proxyURLForAsset($0["url"].stringValue)!),
                resolution: Stream.Resolution.from(resolution: $0["resolution"].stringValue)!,
                kind: .stream,
                encoding: $0["encoding"].stringValue
            )
        }
    }

    private static func extractAdaptiveFormats(from streams: [JSON]) -> [Stream] {
        let audioAssetURL = streams.first { $0["type"].stringValue.starts(with: "audio/mp4") }
        guard audioAssetURL != nil else {
            return []
        }

        let videoAssetsURLs = streams.filter { $0["type"].stringValue.starts(with: "video/mp4") && $0["encoding"].stringValue == "h264" }

        return videoAssetsURLs.map {
            Stream(
                audioAsset: AVURLAsset(url: InvidiousAPI.proxyURLForAsset(audioAssetURL!["url"].stringValue)!),
                videoAsset: AVURLAsset(url: InvidiousAPI.proxyURLForAsset($0["url"].stringValue)!),
                resolution: Stream.Resolution.from(resolution: $0["resolution"].stringValue)!,
                kind: .adaptive,
                encoding: $0["encoding"].stringValue
            )
        }
    }

    static func == (lhs: Video, rhs: Video) -> Bool {
        lhs.id == rhs.id
    }
}
