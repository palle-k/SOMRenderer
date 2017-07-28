//
//  main.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 29.04.17.
//  Copyright (c) 2017 Palle Klewitz
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.


import Foundation
import CoreGraphics
import Progress
import Commander

import MovieLensTools
import SOMKit

// Create a group of commands: train and render

let main = command(
	Argument("map", description: "Path to the self organizing map", validator: String.init(validateExisting: )),
	Argument("tags", description: "Path to a CSV file containing names for the features of the dataset", validator: String.init(validateExisting: )),
	Argument("dataset", description: "Path to the dataset file", validator: String.init(validateExisting: )),
	Argument<String>("o", description: "Save path for the rendered map")
) { mapFilePath, tagsFilePath, movieTagsFilePath, outputFilePath in
	
	let tagsURL = URL(fileURLWithPath: tagsFilePath)
	let mapURL = URL(fileURLWithPath: mapFilePath)
	let movieTagsURL = URL(fileURLWithPath: movieTagsFilePath)
	let saveURL = URL(fileURLWithPath: outputFilePath)
	
	// Loading data
	
	print("Parsing map...")
	let map = try SelfOrganizingMap(contentsOf: mapURL)
	
	print("Parsing tags...")
	let tags = try GenomeParser.parseTags(at: tagsURL)
	
	print("Parsing movie tags...")
	let movieTags = try GenomeParser.parseMovieVectors(at: movieTagsURL)
	
	// Setting up render contexts
	print("Rendering...")
	var renderer = SOMUMatrixRenderer(map: map, mode: .distance)
	renderer.drawsScale = true
	
	guard let context = CGContext(saveURL as CFURL, mediaBox: [CGRect(x: 0, y: 0, width: 620, height: 600)], nil) else {
		fatalError("Could not render image. Context could not be created.")
	}
	
	// Render first page: U-Matrix
	context.beginPDFPage(nil)
	context.translateBy(x: 10, y: 10)
	renderer.title = "Inverse Map Density"
	renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
	context.endPDFPage()
	
	// Render Component Planes
	for i in Progress(0 ..< tags.count)
	{
		context.beginPDFPage(nil)
		context.translateBy(x: 10, y: 10)
		renderer.title = tags[i + 1] ?? "Unknown Tag"
		renderer.viewMode = .feature(index: i)
		renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
		context.endPDFPage()
	}
	
	// Render Dataset Density
	context.beginPDFPage(nil)
	context.translateBy(x: 10, y: 10)
	renderer.title = "Log Dataset Density"
	renderer.viewMode = .density(dataset: movieTags.map{$0.1})
	renderer.render(in: context, size: CGSize(width: 600, height: 600 / renderer.aspectRatio))
	context.endPDFPage()
	
	// Finish rendering
	context.flush()
	
} // End command render

main.run()
