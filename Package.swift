// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "SOMRenderer",
    dependencies: [
		.Package(url: "https://github.com/jkandzi/Progress.swift", majorVersion: 0),
		.Package(url: "https://github.com/kylef/Commander.git", majorVersion: 0)
	]
)
