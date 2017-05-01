//
//  main.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 29.04.17.
//  Copyright © 2017 Palle Klewitz. All rights reserved.
//

import Foundation
import CoreGraphics
import Cocoa
import Progress

guard CommandLine.arguments.count > 1 else
{
	fatalError("No output file specified")
}

let baseURL = URL(fileURLWithPath: "/Users/Palle/Downloads/ml-20m/")

print("Parsing tags...")

let tagsURL: URL

if #available(OSX 10.11, *)
{
	tagsURL = URL(fileURLWithPath: "genome-tags.csv", relativeTo: baseURL)
}
else
{
	tagsURL = baseURL.appendingPathComponent("genome-tags.csv")
}

let tags = try GenomeParser.parseTags(at: tagsURL)

print("Parsing movie tags...")
let vectorURL = URL(fileURLWithPath: "/Users/Palle/Desktop/movietags.csv")
let movieVectors = try GenomeParser.parseMovieVectors(at: vectorURL)

print("Done. Beginning training...")

srand48(time(nil))

let map = SelfOrganizingMap(30, 30, outputSize: tags.count)

let epochs = 10_000_000

for epoch in Progress(0 ..< epochs)
{
	map.update(with: movieVectors.random().1, totalIterations: epochs * 4 / 5, currentIteration: epoch)
}

var renderer = SOMUMatrixRenderer(map: map, mode: .distance)
//let renderer = SOMInputSpaceRenderer(map: map)

let url = URL(fileURLWithPath: CommandLine.arguments[1])

guard let context = CGContext(url as CFURL, mediaBox: [CGRect(x: 0, y: 0, width: 600 + 20, height: 600 + 20)], nil) else
{
	fatalError("Could not render image. Context could not be created.")
}

renderer.drawsScale = true

context.beginPDFPage(nil)
context.translateBy(x: 10, y: 10)
renderer.title = "Map Density"
renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
context.endPDFPage()

for i in 0 ..< tags.count
{
	context.beginPDFPage(nil)
	context.translateBy(x: 10, y: 10)
	renderer.title = tags[i] ?? "Unknown Tag"
	renderer.viewMode = .feature(index: i)
	renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
	context.endPDFPage()
}

context.beginPDFPage(nil)
context.translateBy(x: 10, y: 10)
renderer.title = "Log Dataset Density"
renderer.viewMode = .density(dataset: movieVectors.map{$0.1})
renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
context.endPDFPage()

//context.beginPDFPage(nil)
//context.translateBy(x: 10, y: 10)
//SOMInputSpaceRenderer(map: map).render(in: context, size: CGSize(width: 600, height: 600))
//context.endPDFPage()

context.flush()
