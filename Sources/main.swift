//
//  main.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 29.04.17.
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


import Foundation
import CoreGraphics
import Cocoa
import Progress
import Commander


struct ValidationError: Error
{
	let description: String
}

extension Int
{
	init(validatePositive value: Int) throws
	{
		guard value > 0 else
		{
			throw ValidationError(description: "Value \(value) expected to be positive.")
		}
		
		self = value
	}
}

extension Float
{
	init(validatePositive value: Float) throws
	{
		guard value > 0 else
		{
			throw ValidationError(description: "Value \(value) expected to be positive.")
		}
		
		self = value
	}
}

extension String
{
	init(validateExisting path: String) throws
	{
		guard FileManager.default.fileExists(atPath: path) else
		{
			throw ValidationError(description: "File \(path) does not exist.")
		}
		
		self = path
	}
}

let group = Group { group in
	
	group.command(
		"train",
		Argument<Int>("map-width", description: "Width of the SOM", validator: Int.init(validatePositive: )),
		Argument<Int>("map-height", description: "Height of the SOM", validator: Int.init(validatePositive: )),
		Argument<Int>("epochs", description: "Number of epochs to train", validator: Int.init(validatePositive: )),
		Argument<String>("tags", description: "Path to the genome-tags.csv file", validator: String.init(validateExisting: )),
		Argument<String>("movie-tags", description: "Path to the movietags.csv file", validator: String.init(validateExisting: )),
		Argument<String>("o", description: "Save path for the self organizing map"),
		Option("nscale", 1, flag: nil, description: "Scale of neighbourhood", validator: Float.init(validatePositive: ))
	) { mapWidth, mapHeight, epochs, tagsFilePath, movieTagsFilePath, mapFilePath, neighbourhoodScale in
		
		let tagsURL = URL(fileURLWithPath: tagsFilePath)
		let movieTagsURL = URL(fileURLWithPath: movieTagsFilePath)
		let mapURL = URL(fileURLWithPath: mapFilePath)
		
		print("Parsing tags...")
		let tags = try GenomeParser.parseTags(at: tagsURL)
		
		print("Parsing movie tags...")
		let movieVectors = try GenomeParser.parseMovieVectors(at: movieTagsURL)
		print("Done. Beginning training...")
		
		let map = SelfOrganizingMap(mapWidth, mapHeight, outputSize: tags.count)
		
		for epoch in Progress(0 ..< epochs)
		{
			map.update(with: movieVectors.random().1, totalIterations: epochs * 4 / 5, currentIteration: epoch, neighbourhoodScale: neighbourhoodScale)
		}
		
		try map.write(to: mapURL)
	}
	
	group.command(
		"render",
		Argument<String>("map", description: "Path to the self organizing map", validator: String.init(validateExisting: )),
		Argument<String>("tags", description: "Path to the genome-tags.csv file", validator: String.init(validateExisting: )),
		Argument<String>("movie-tags", description: "Path to the movietags.csv file", validator: String.init(validateExisting: )),
		Argument<String>("o", description: "Save path for the rendered map")
	) { mapFilePath, tagsFilePath, movieTagsFilePath, outputFilePath in
		
		let tagsURL = URL(fileURLWithPath: tagsFilePath)
		let mapURL = URL(fileURLWithPath: mapFilePath)
		let movieTagsURL = URL(fileURLWithPath: movieTagsFilePath)
		let saveURL = URL(fileURLWithPath: outputFilePath)
		
		print("Parsing map...")
		let map = try SelfOrganizingMap(contentsOf: mapURL)
		
		print("Parsing tags...")
		let tags = try GenomeParser.parseTags(at: tagsURL)
		
		print("Parsing movie tags...")
		let movieTags = try GenomeParser.parseMovieVectors(at: movieTagsURL)
		
		print("Rendering...")
		var renderer = SOMUMatrixRenderer(map: map, mode: .distance)
		renderer.drawsScale = true
		
		guard let context = CGContext(saveURL as CFURL, mediaBox: [CGRect(x: 0, y: 0, width: 600 + 20, height: 600 + 20)], nil) else
		{
			fatalError("Could not render image. Context could not be created.")
		}
		
		context.beginPDFPage(nil)
		context.translateBy(x: 10, y: 10)
		renderer.title = "Inverse Map Density"
		renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
		context.endPDFPage()
		
		for i in Progress(0 ..< tags.count)
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
		renderer.viewMode = .density(dataset: movieTags.map{$0.1})
		renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
		context.endPDFPage()
		
		context.flush()
	}
}

group.run()


