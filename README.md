[![Platforms](https://img.shields.io/badge/platforms-Mac%20|%20Linux%20|%20Windows-lightgray.svg)](https://github.com/swhitty/FlyingFoxCLI/blob/main/Package.swift)
[![Swift 5.5](https://img.shields.io/badge/swift-5.5-red.svg?style=flat)](https://developer.apple.com/swift)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://opensource.org/licenses/MIT)

# SimpleOCRServer

A simple server that uses [FlyingFox](https://github.com/swhitty/FlyingFox) to handle requests and the [Apple Vision Framework](https://developer.apple.com/documentation/vision) to perform OCR on images.

### Run

```
% swift run simple_ocr_server
```

Supply a port number:

```
% swift run simple_ocr_server --port 8008
```

Listen on a [UNIX-domain](https://www.freebsd.org/cgi/man.cgi?query=unix) socket:

```
% swift run simple_ocr_server --path foo
```

### Request

```
% curl --location 'http://localhost:80/ocr' --header 'Content-Type: text/plain' --data '@/path/to/file.jpg'
```
