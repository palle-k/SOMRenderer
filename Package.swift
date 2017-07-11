// swift-tools-version:4.0

//  Package.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 01.05.17.
//	Copyright (c) 2017 Palle Klewitz
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//	SOFTWARE.


import PackageDescription

let package = Package(
    name: "SOMTools",
    dependencies: [
		.package(url: "https://github.com/jkandzi/Progress.swift", from: "0.0.0"),
		.package(url: "https://github.com/kylef/Commander.git", from: "0.0.0"),
		.package(url: "https://github.com/IBM-Swift/Kitura.git", from: "1.7.0"),
		.package(url: "https://github.com/IBM-Swift/Kitura-CORS.git", from: "1.7.0"),
		.package(url: "https://github.com/palle-k/OpenGraph.git", from: "1.0.3"),
		.package(url: "https://github.com/IBM-Swift/Kitura-Cache.git", from: "1.7.0")
	],
    targets: [
		.target(name: "SOMKit", dependencies: ["Progress"], path: "Sources/SOMKit"),
		.target(name: "MovieLensTools", dependencies: ["Progress", "SOMKit"], path: "Sources/MovieLens Tools"),
		.target(name: "SOMTrainer", dependencies: ["Progress", "Commander", "SOMKit", "MovieLensTools"], path: "Sources/SOM Trainer"),
		.target(name: "SOMRenderer", dependencies: ["Progress", "Commander", "SOMKit", "MovieLensTools"], path: "Sources/SOM Renderer"),
		.target(name: "SOMServer", dependencies: ["Progress", "Commander", "Kitura", "KituraCORS", "KituraCache", "SOMKit", "MovieLensTools", "OpenGraph"], path: "Sources/SOM Server")
    ]
)
