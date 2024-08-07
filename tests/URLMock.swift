import Foundation
import URLMockProtocol
import XCTest

class URLMockTests: XCTestCase {

    func testMatchings() {
        var mock: URLMock
        var request: URLRequest
        let response = URLMock.Response.response(statusCode: 200, headers: nil, body: .none)

        request = URLRequest(url: URL(string: "https://host.com/path1/path2/path3")!)
        request.httpMethod = "POST"

        // HTTP method
        mock = URLMock(when: [.httpMethod("POST")], with: response)
        XCTAssertTrue(mock.matches(request: request))

        request.httpMethod = "GET"
        XCTAssertFalse(mock.matches(request: request))

        // URL Path
        mock = URLMock(
            when: [.stringURL("https://host.com/path1/path2/path3"), .httpMethod("GET")],
            with: response
        )
        XCTAssertTrue(mock.matches(request: request))

        mock = URLMock(
            when: [.stringURL("https://host.com/path1/path2/124412"), .httpMethod("GET")],
            with: response
        )
        XCTAssertFalse(mock.matches(request: request))

        mock = URLMock(
            when: [.stringURL("https://*/path1/path2/path3"), .httpMethod("GET")],
            with: response
        )
        XCTAssertTrue(mock.matches(request: request))

        mock = URLMock(
            when: [.stringURL("https://*/*/path2/*"), .httpMethod("GET")],
            with: response
        )
        XCTAssertTrue(mock.matches(request: request))

        mock = URLMock(
            when: [.stringURL("https://host.com/path1/**"), .httpMethod("GET")],
            with: response
        )
        XCTAssertTrue(mock.matches(request: request))

        mock = URLMock(
            when: [.stringURL("https://host.com/9178624/**"), .httpMethod("GET")],
            with: response
        )
        XCTAssertFalse(mock.matches(request: request))

        // Headers
        request.allHTTPHeaderFields = ["headerKey": "headerValue"]
        mock = URLMock(
            when: [.headerParam(key: "headerKey", value: "headerValue")],
            with: response
        )
        XCTAssertTrue(mock.matches(request: request))

        mock = URLMock(
            when: [.headerParam(key: "headerKey", value: "wrongValue")],
            with: response
        )
        XCTAssertFalse(mock.matches(request: request))

        // Query Params
        request = URLRequest(url: URL(string: "https://host.com/path1/path2/path3?queryParam1=query1&queryParam2=query2")!)
        mock = URLMock(
            when: [.queryParam(key: "queryParam1", value: "query1")],
            with: response
        )
        XCTAssertTrue(mock.matches(request: request))

        mock = URLMock(
            when: [.queryParam(key: "queryParam2", value: "12345")],
            with: response
        )
        XCTAssertFalse(mock.matches(request: request))

        // Path Extension
        request = URLRequest(url: URL(string: "https://host.com/pathToImage/image.png")!)
        mock = URLMock(
            when: [.pathExtension("png")],
            with: response
        )
        XCTAssertTrue(mock.matches(request: request))

        mock = URLMock(
            when: [.pathExtension("jpg")],
            with: response
        )
        XCTAssertFalse(mock.matches(request: request))

        // JSON Body
        request = URLRequest(url: URL(string: "https://host.com/path")!)
        request.httpBody = try! JSONSerialization.data(withJSONObject: [
            "name": "iOSDev",
            "age": 45,
            "email": "iosDev@mail.com",
            "nullable": nil,
            "pull_requests": ["SCMI-1", "SCMI-2", "SCMI-3"],
            "comments": ["title1": "comment1", "title2": "comment2"]
        ])
        mock = URLMock(
            when: [Matching.bodyJSONObject([
                "name": "iOSDev",
                "age": 45,
                "nullable": nil,
                "comments": ["title2": "comment2"]
            ])],
            with: response
        )
        XCTAssertTrue(mock.matches(request: request))

        mock = URLMock(
            when: [Matching.bodyJSONObject(["name": "iOSDev", "age": 99, "nullable": nil])],
            with: response
        )
        XCTAssertFalse(mock.matches(request: request))

        mock = URLMock(
            when: [Matching.bodyJSONObject([
                "name": "iOSDev",
                "age": 45,
                "nullable": nil,
                "comments": ["title2": "wrongComment"]
            ])],
            with: response
        )
        XCTAssertFalse(mock.matches(request: request))

        mock = URLMock(
            when: [Matching.bodyJSONObject([
                "pull_requests": ["SCMI-1", "SCMI-2", "SCMI-3"]
            ])],
            with: response
        )
        XCTAssertTrue(mock.matches(request: request))

        mock = URLMock(
            when: [Matching.bodyJSONObject([
                "pull_requests": ["SCMI-1", "SCMI-3"]
            ])],
            with: response
        )
        XCTAssertFalse(mock.matches(request: request))
    }
}

