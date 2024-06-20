import Foundation
import UIKit

public class URLMockStore {
    public static let shared = URLMockStore()
    private var mocks: [URLMock] = []

    private init() {}

    public static func getMock(from: URLRequest) -> URLMock? {
        return shared.mocks.first (where: { m in
            m.matches(request: from)
        })
    }

    public static func add(_ urlMock: URLMock) {
        shared.mocks.insert(urlMock, at: 0)
    }

    public static func add(_ urlMocks: [URLMock]) {
        shared.mocks.insert(contentsOf: urlMocks, at: 0)
    }

    public static func set(_ urlMock: URLMock) {
        shared.mocks.removeAll()
        shared.mocks.append(urlMock)
    }

    public static func set(_ urlMocks: [URLMock]) {
        shared.mocks.removeAll()
        shared.mocks.append(contentsOf: urlMocks)
    }

    public static func reset() {
        shared.mocks.removeAll()
    }

    public static func all() -> [URLMock] {
        shared.mocks
    }
}

public enum Matching: Codable {
    case url(URL)
    case stringURL(String)
    case httpMethod(String)
    case queryParam(key: String, value: String?)
    case headerParam(key: String, value: String)
    case pathExtension(String)
}

public class URLMock: Codable {

    public class Response: Codable {
        public enum Body: Codable {
            case none
            case data(Data)
            case string(String)
            case forceError(code: Int, domain: String)

            public static func fromJSON(fileName: String, bundle: Bundle) -> Self {
                guard let url = bundle.url(forResource: fileName, withExtension: "json"),
                      let data = try? Data(contentsOf: url) else {
                    URLMockProtocol.onFailedLoadingJSON(fileName)
                    return .forceError(code: 0, domain: "JSON mock file: \(fileName) not found!")
                }
                return .data(data)
            }
        }

        public enum CachePolicy: Codable {
            case allowed
            case allowedInMemoryOnly
            case notAllowed
        }

        public let statusCode: Int
        public let headers: [String: String]?
        public let body: Body
        public var cacheStoragePolicy: CachePolicy = .notAllowed
        public var httpVersion: String = "HTTP/1.1"

        public init(statusCode: Int, headers: [String : String]?, body: Body) {
            self.statusCode = statusCode
            self.headers = headers
            self.body = body
        }

        public init(statusCode: Int, headers: [String : String]?, body: Body, cacheStoragePolicy: CachePolicy, httpVersion: String) {
            self.statusCode = statusCode
            self.headers = headers
            self.body = body
            self.cacheStoragePolicy = cacheStoragePolicy
            self.httpVersion = httpVersion
        }

        public static func response(statusCode: Int, headers: [String : String]?, body: Body) -> Response {
            Response(statusCode: statusCode, headers: headers, body: body)
        }
    }

    public enum Mode: Codable {
        case response(Response)
        case excludeResponse
    }

    public let mode: Mode
    public let matchings: [Matching]
    public var delay: Double? // Seconds

    public init(when: Matching, with: Response) {
        self.matchings = [when]
        self.mode = .response(with)
        self.delay = nil
    }

    public init(when: [Matching], with: Response) {
        self.matchings = Array(when)
        self.mode = .response(with)
        self.delay = nil
    }

    public init(when: [Matching], with: Response, delay: Double) {
        self.matchings = Array(when)
        self.mode = .response(with)
        self.delay = delay
    }

    public init(excludeWhen: [Matching]) {
        self.mode = .excludeResponse
        self.matchings = Array(excludeWhen)
        self.delay = nil
    }

    public static func mock(when: Matching, with: Response) -> URLMock {
        URLMock(when: when, with: with)
    }

    public static func mock(when: [Matching], with: Response) -> URLMock {
        URLMock(when: when, with: with)
    }

    public func matches(matching: Matching, request: URLRequest) -> Bool {
        // https://www.avanderlee.com/swift/url-components/
        switch matching {
        case .url(let url):
            guard let requestURL = request.url,
                  let requestUrlComponents = URLComponents(string: requestURL.absoluteString),
                  let mockUrlComponents = URLComponents(string: url.absoluteString) else {
                return false
            }

            guard requestUrlComponents.host == mockUrlComponents.host || mockUrlComponents.host == "*" else {
                return false
            }

            let componentsCount = requestURL.pathComponents.count
            var idx = 0

            while idx < componentsCount {
                guard idx < url.pathComponents.count else {
                    return false
                }
                let requestComponent = requestURL.pathComponents[idx]
                let mockComponent = url.pathComponents[idx]

                if mockComponent == "*" {
                    // matches
                } else if mockComponent == "**" {
                    return true
                } else if requestComponent == mockComponent {
                    // matches
                } else {
                    return false
                }
                idx += 1
            }
            return true
        case .stringURL(let string):
            guard let url = URL(string: string) else { return false }
            return matches(matching: .url(url), request: request)
        case .httpMethod(let string):
            return string == request.httpMethod
        case .queryParam(let key, let value):
            guard let requestURL = request.url,
                  let requestUrlComponents = URLComponents(string: requestURL.absoluteString),
                  let queryItems = requestUrlComponents.queryItems else { return false }

            for queryItem in queryItems {
                if queryItem.name == key && queryItem.value == value {
                    return true
                }
            }
            return false
        case .headerParam(let key, let value):
            guard let headers = request.allHTTPHeaderFields else { return false }
            for header in headers {
                if header.key == key && header.value == value {
                    return true
                }
            }
            return false
        case .pathExtension(let fileExtension):
            guard let requestURL = request.url else {
                return false
            }
            return requestURL.pathExtension == fileExtension
        }
    }

    public func matches(request: URLRequest) -> Bool {
        for matching in matchings {
            if !matches(matching: matching, request: request) {
                return false
            }
        }
        return true
    }
}

public class URLMockProtocol: URLProtocol {

    public static var failWhenMockNotFound = true
    public static var onURLMockNotFound: (URLRequest) -> Void = { request in
        print(MockError.mockNotFound(request).debugDescription)
    }

    public static var onFailedLoadingJSON: (String) -> Void = { fileName in
        print(MockError.jsonFileForMockNotFound(fileName).debugDescription)
    }

    public enum MockError: Error, LocalizedError, CustomDebugStringConvertible {
        case mockNotFound(URLRequest)
        case jsonFileForMockNotFound(String)
        case cantCreateHTTPResponse(URLMock.Response)

        public var debugDescription: String {
            switch self {
            case .mockNotFound(let request):
                return "URLMock NOT found for this Request: \(request.url?.absoluteString ?? "")"
            case .jsonFileForMockNotFound(let fileName):
                return "JSON mock file can't be loaded: \(fileName)"
            case .cantCreateHTTPResponse(let response):
                return "Can't create HTTPResponse from response: \(response)"
            }
        }
    }

    static public override func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    static public override func canInit(with request: URLRequest) -> Bool {
        if let mock = URLMockStore.getMock(from: request) {
            switch mock.mode {
            case .response: return true
            case .excludeResponse: return false
            }
        } else {
            onURLMockNotFound(request)
            if Self.failWhenMockNotFound {
                return true
            } else {
                return false
            }
        }
    }

    override public func startLoading() {
        Task(priority: .userInitiated) {
            if let mock = URLMockStore.getMock(from: request) {
                if let delay = mock.delay {
                    try? await Task.sleep(nanoseconds: UInt64(Double(1_000_000_000) * delay))
                }
                switch mock.mode {
                case .response(let response):
                    let httpResponse: HTTPURLResponse? = HTTPURLResponse(
                        url: request.url!,
                        statusCode: response.statusCode,
                        httpVersion: response.httpVersion,
                        headerFields: response.headers
                    )

                    let data: Data
                    var getBodyError: Error?
                    switch response.body {
                    case .none:
                        data = Data()
                    case .data(let mockData):
                        data = mockData
                    case .string(let string):
                        data = Data(string.utf8)
                    case .forceError(let code, let domain):
                        data = Data()
                        getBodyError = NSError(domain: domain, code: code)
                    }

                    if let getBodyError = getBodyError {
                        self.client?.urlProtocol(self, didFailWithError: getBodyError)
                    } else if let httpResponse = httpResponse {
                        let policy: URLCache.StoragePolicy
                        switch response.cacheStoragePolicy {
                        case .allowed: policy = .allowed
                        case .allowedInMemoryOnly: policy = .allowedInMemoryOnly
                        case .notAllowed: policy = .notAllowed
                        }
                        self.client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: policy)
                        self.client?.urlProtocol(self, didLoad: data)
                        self.client?.urlProtocolDidFinishLoading(self)
                    } else {
                        client?.urlProtocol(self, didFailWithError: MockError.cantCreateHTTPResponse(response))
                    }
                case .excludeResponse: break //unreachable
                }
            } else {
                client?.urlProtocol(self, didFailWithError: MockError.mockNotFound(request))
            }
        }
    }

    override public func stopLoading() {}
}

public class XCUITestURLMock {

    public static let shared = XCUITestURLMock()
    public var buttonsCenter = CGPoint(x: 0, y: 100)
    public var hidePasteButtonWhenFirstDataIsReceived = true

    private var pasteButton: UIControl?

    private init() {}

    public static func prepareToLoadDataFromUITests(uiResponder: UIResponder, rootView: UIView) {
        if #available(iOS 16.0, *) {
            let showButton = UIButton()
            showButton.backgroundColor = .green.withAlphaComponent(0.1)
            showButton.setTitle("", for: .normal)
            showButton.accessibilityLabel = "URLMOCK_SHOW_PASTE_BUTTON"
            showButton.frame = CGRect(x: shared.buttonsCenter.x, y: shared.buttonsCenter.y, width: 8, height: 8)
            showButton.addTarget(shared, action: #selector(showPasteButton), for: .touchUpInside)
            rootView.addSubview(showButton)

            let configuration = UIPasteControl.Configuration()
            configuration.baseBackgroundColor = .blue
            configuration.baseForegroundColor = .white
            configuration.cornerStyle = .medium
            configuration.displayMode = .iconAndLabel

            let pasteButton = UIPasteControl(configuration: configuration)
            shared.pasteButton = pasteButton
            pasteButton.frame = CGRect(x: shared.buttonsCenter.x, y: shared.buttonsCenter.y + 8, width: 140, height: 44)
            rootView.addSubview(pasteButton)
            pasteButton.target = uiResponder
            pasteButton.isHidden = true
        }
    }

    @objc private func showPasteButton(_ sender: UIButton) {
        Self.setPasteButton(isHidden: false)
    }

    public static func sendToPasteboard(mocks: [URLMock]) {
        let data = try! JSONEncoder().encode(mocks)
        let pasteboard = UIPasteboard.general
        pasteboard.setData(data, forPasteboardType: "XCUITEST_URLMOCK")
    }

    public static func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
        return itemProviders.first(where: { itemProvider in
            itemProvider.hasItemConformingToTypeIdentifier("XCUITEST_URLMOCK")
        }) != nil
    }

    public static func paste(itemProviders: [NSItemProvider]) {
        if #available(iOS 16.0, *) {
            for itemProvider in itemProviders {
                itemProvider.loadDataRepresentation(forTypeIdentifier: "XCUITEST_URLMOCK") { (data: Data?, error: (any Error)?) in
                    if let jsonData = data {
                        if let mocks: [URLMock] = try? JSONDecoder().decode([URLMock].self, from: jsonData) {
                            URLMockStore.add(mocks)
                            print("Mocks loaded: \(mocks.count)")
                        }
                    }
                }
            }

            if shared.hidePasteButtonWhenFirstDataIsReceived {
                Self.setPasteButton(isHidden: true)
            }
        }
    }

    public static func setPasteButton(isHidden: Bool) {
        shared.pasteButton?.isHidden = isHidden
    }
}
