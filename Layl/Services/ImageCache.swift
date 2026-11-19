import UIKit

actor ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 180
        return cache
    }()
    private var tasks: [URL: Task<UIImage?, Never>] = [:]

    func image(for url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        if let existing = tasks[url] { return await existing.value }
        let task = Task<UIImage?, Never> {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 20
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
                return UIImage(data: data)
            } catch {
                return nil
            }
        }
        tasks[url] = task
        let image = await task.value
        tasks[url] = nil
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }
}
