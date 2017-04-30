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

guard CommandLine.arguments.count > 1 else
{
	fatalError("No output file specified")
}


let sourceURL = URL(fileURLWithPath: "/Users/Palle/Downloads/ml-20m/movies.csv")
let contents = try! String(contentsOf: sourceURL)
let lines = contents.components(separatedBy: .newlines)

let movies = (lines.filter{!$0.isEmpty}.dropFirst())
	
let movieTable = movies
	.map { movie -> [String] in
		return movie.components(separatedBy: ",")
	}
	.map { movie -> (Int, String, String) in
		return (
			Int(movie[0]) ?? 0,
			Array(movie[1..<(movie.endIndex-1)]).joined(separator: ","),
			movie.last!
		)
	}

let allMovies = movieTable.map { (id, title, genres) -> (id: Int, title: String, genres: Set<String>) in
	return (id: id, title: title, genres: Set(genres.components(separatedBy: "|")))
}

let genres: Set<String> = allMovies
	.map { movie -> Set<String> in
		movie.genres
	}
	.reduce([], {$0.union($1)})

let sortedGenres = genres.symmetricDifference(["(no genres listed)"]).sorted()

func genreVector(`for` genres: Set<String>) -> [Float] {
	return sortedGenres.map{genres.contains($0)}.map{$0 ? 1 : 0}
}

let movieVectors = allMovies.map{($0.title, genreVector(for: $0.genres))}.filter{$0.1.max()! != 0}


srand48(time(nil))

let map = SelfOrganizingMap(20, 20, outputSize: sortedGenres.count)

let epochs = 100_000

for epoch in 0 ..< epochs
{
	map.update(with: movieVectors.random().1, totalIterations: epochs / 10, currentIteration: epoch)
	
	if epoch % (epochs / 100) == 0
	{
		print("Training: \(epoch / (epochs / 100))% completed.")
	}
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
renderer.title = "U-Matrix"
renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
context.endPDFPage()

for i in sortedGenres.indices
{
	context.beginPDFPage(nil)
	context.translateBy(x: 10, y: 10)
	renderer.title = sortedGenres[i]
	renderer.viewMode = .feature(index: i)
	renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
	context.endPDFPage()
}

context.beginPDFPage(nil)
context.translateBy(x: 10, y: 10)
renderer.title = "Density"
renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
context.endPDFPage()

//context.beginPDFPage(nil)
//context.translateBy(x: 10, y: 10)
//SOMInputSpaceRenderer(map: map).render(in: context, size: CGSize(width: 600, height: 600))
//context.endPDFPage()

context.flush()
