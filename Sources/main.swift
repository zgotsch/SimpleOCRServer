// main.swift
// SimpleOCRServer
//
// Based on FlyingFoxCLI by Simon Whitty
//
// Copyright 2023 Zach Gotsch
// Copyright 2022 Simon Whitty
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
// associated documentation files (the “Software”), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute,
// sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or
// substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
// NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import CoreGraphics
import FlyingFox
import Foundation
import Vision

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(WinSDK)
  import WinSDK.WinSock2
#endif

extension CGPoint {
  func scale(by scale: CGSize) -> CGPoint {
    CGPoint(x: x * scale.width, y: y * scale.height)
  }
}

enum VisionError: Error {
  case missingResults
}

struct SimpleObservation: Codable {
  struct SimpleRect: Codable {
    let bottomLeft: CGPoint
    let bottomRight: CGPoint
    let topLeft: CGPoint
    let topRight: CGPoint
  }

  let bbox: SimpleRect
  let confidence: Float
  let label: String

  init(observation: VNRecognizedTextObservation, imageSize: CGSize) {
    self.bbox = SimpleRect(
      bottomLeft: observation.bottomLeft.scale(by: imageSize),
      bottomRight: observation.bottomRight.scale(by: imageSize),
      topLeft: observation.topLeft.scale(by: imageSize),
      topRight: observation.topRight.scale(by: imageSize))
    self.confidence = observation.confidence
    self.label = observation.topCandidates(1).first?.string ?? ""
  }
}

func dataToCGImage(data: Data) -> CGImage? {
  guard let dataProvider = CGDataProvider(data: data as CFData) else {
    print("Failed to create CGDataProvider")
    return nil
  }

  guard
    let cgImage = CGImage(
      jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true,
      intent: .defaultIntent)
  else {
    print("Failed to create CGImage")
    return nil
  }

  return cgImage
}

func makeServer(from args: [String] = Swift.CommandLine.arguments) -> HTTPServer {
  guard let path = parsePath(from: args) else {
    return HTTPServer(
      port: parsePort(from: args) ?? 80,
      logger: .print(category: "SimpleOCRServer"))
  }
  var addr = sockaddr_un.unix(path: path)
  unlink(&addr.sun_path.0)
  return HTTPServer(
    address: addr,
    logger: .print(category: "SimpleOCRServer"))
}

func parsePath(from args: [String]) -> String? {
  var last: String?
  for arg in args {
    if last == "--path" {
      return arg
    }
    last = arg
  }
  return nil
}

func parsePort(from args: [String]) -> UInt16? {
  var last: String?
  for arg in args {
    if last == "--port" {
      return UInt16(arg)
    }
    last = arg
  }
  return nil
}

let server = makeServer()

await server.appendRoute("/ping") { _ in
  HTTPResponse(
    statusCode: .ok,
    headers: [.contentType: "text/plain; charset=UTF-8"],
    body: "pong".data(using: .utf8)!)
}

await server.appendRoute("/ocr") { req in
  guard let bodyImage = dataToCGImage(data: try! await req.bodyData) else {
    return HTTPResponse(
      statusCode: HTTPStatusCode.badRequest, body: "Could not create CGImage".data(using: .utf8)!)
  }

  let requestHandler = VNImageRequestHandler(cgImage: bodyImage)

  let result = await withCheckedContinuation {
    (continuation: CheckedContinuation<Result<[SimpleObservation], Error>, Never>) in
    func recognizeTextHandler(request: VNRequest, error: Error?) {
      if let error = error {
        continuation.resume(returning: .failure(error))
        return
      }

      guard let observations = request.results as? [VNRecognizedTextObservation] else {
        continuation.resume(returning: .failure(VisionError.missingResults))
        return
      }

      let simpleObservations = observations.map { observation in
        return SimpleObservation(
          observation: observation,
          imageSize: CGSize(width: bodyImage.width, height: bodyImage.height))
      }

      continuation.resume(returning: .success(simpleObservations))
    }
    let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
    do {
      try requestHandler.perform([request])
    } catch {
      print("Unable to perform the requests: \(error).")
      continuation.resume(returning: .failure(error))
    }
  }

  switch result {
  case .success(let observations):
    // JSONify observations
    return HTTPResponse(
      statusCode: .ok,
      headers: [.contentType: "application/json; charset=UTF-8"],
      body: try! JSONEncoder().encode(observations))
  case .failure(let error):
    return HTTPResponse(
      statusCode: HTTPStatusCode.internalServerError,
      body: "Could not recognize text: \(error)".data(using: .utf8)!)
  }
}

try await server.start()
