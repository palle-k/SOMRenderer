//
//  main.swift
//  SOMTrainingVisualizer
//
//  Created by Palle Klewitz on 28.07.2017.
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
import SOMKit
import Commander
import Progress

srand48(time(nil))

let main = command(
	Argument<Int>("step", description: "Number of iterations to be performed between renderings", validator: Int.init(validatePositive:)),
	Argument<Int>("iterations", description: "Total number of iterations to perform", validator: Int.init(validatePositive:)),
	Argument<String>("output", description: "Output path for the visualization to be written to", validator: nil)
) { step, iterations, output in
	let outputURL = URL(fileURLWithPath: output)
	
	let map = SelfOrganizingMap(20, 20, outputSize: 2, distanceFunction: manhattanDistance)
	let renderer = SOMInputSpaceRenderer(map: map, type: .grid)
	
	guard let context = CGContext(outputURL as CFURL, mediaBox: [CGRect(x: 0, y: 0, width: 620, height: 600)], nil) else {
		fatalError("Could not render image. Context could not be created.")
	}
	
	for iteration in Progress(0 ... iterations) {
		map.update(with: randomSquarePoint(), totalIterations: iterations, currentIteration: iteration, neighbourhoodScale: 1)
		
		if iteration % step == 0 {
			context.beginPDFPage(nil)
			context.translateBy(x: 10, y: 10)
			renderer.render(in: context, size: CGSize(width: 600, height: 580))
			context.endPDFPage()
		}
	}
	
	context.flush()
}

main.run()
