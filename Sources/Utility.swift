//
//  Utility.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 30.04.17.
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
import Accelerate
import Progress


extension Array
{
	static func distanceSq(from: [Float], to: [Float]) -> Float
	{
		precondition(from.count == to.count, "Vectors must have equal dimension.")
		var result: Float = 0
		
//		let temp = UnsafeMutablePointer<Float>.allocate(capacity: from.count)
//		defer { temp.deallocate(capacity: from.count) }
//		vDSP_vsub(from, 1, to, 1, temp, 1, vDSP_Length(from.count))
//		vDSP_svemg(temp, 1, &result, vDSP_Length(from.count))
		
		vDSP_distancesq(from, 1, to, 1, &result, vDSP_Length(from.count))
		return result // * result
	}
	
	static func distance(from: [Float], to: [Float]) -> Float
	{
		return sqrt(distanceSq(from: from, to: to))
	}
	
	static func compareDistance(_ reference: [Float]) -> ([Float],[Float]) -> Bool
	{
		return {
			(_ first: [Float], _ second: [Float]) in
			return distanceSq(from: reference, to: first) < distanceSq(from: reference, to: second)
		}
	}
}

extension Array
{
	func minIndex(by compare: @escaping (Element, Element) throws -> Bool) rethrows -> Int?
	{
		return try self.enumerated().min(by: {try compare($0.1, $1.1)})?.0
	}
	
	func random() -> Element
	{
		return self[Int(arc4random_uniform(UInt32(self.count)))]
	}
}

func randomCirclePoint() -> Sample
{
	let t = 2 * Float.pi * Float.random()
	let r = Float.random()
	return [sqrt(r) * cos(t), sqrt(r) * sin(t)]
}

func randomSquarePoint() -> Sample
{
	return [Float.random() * 2 - 1, Float.random() * 2 - 1]
}

func randomCubePoint() -> Sample
{
	return [Float.random() * 2 - 1, Float.random() * 2 - 1, Float.random() * 2 - 1]
}

func randomPlanePoint() -> Sample
{
	let squarePoint = randomSquarePoint()
	let x = squarePoint[0]
	let z = squarePoint[1]
	let y = x * x - z * z * z
	return [x,y,z]
}

extension Float
{
	static func random() -> Float
	{
		return Float(drand48())
	}
}

func hexagonGridDistance(from: (column: Int, row: Int), to: (column: Int, row: Int)) -> Int
{
	func toCubeCoordinates(point: (column: Int, row: Int)) -> (x: Int, y: Int, z: Int)
	{
		let x = point.column - (point.row + (point.row & 1)) / 2
		let z = point.row
		let y = -x - z
		return (x, y, z)
	}
	
	let fromCube = toCubeCoordinates(point: from)
	let toCube = toCubeCoordinates(point: to)
	
	return max(abs(fromCube.x - toCube.x), abs(fromCube.y - toCube.y), abs(fromCube.z - toCube.z))
	//	return (abs(fromCube.x - toCube.x) + abs(fromCube.y - toCube.y) + abs(fromCube.z - toCube.z)) / 2
}

extension Int
{
	func map<Result>(_ transform: (Int) throws -> Result) rethrows -> [Result]
	{
		return try (0 ..< self).map(transform)
	}
}

extension SelfOrganizingMap
{
	func write(to url: URL) throws
	{
		let dimensionsString = self.dimensionSizes.map(String.init).joined(separator: ",")
		
		let nodesString = self.nodes.map { node -> String in
			return node.map(String.init).joined(separator: ",")
		}
		.joined(separator: "\n")
		
		try dimensionsString
			.appending("\n")
			.appending(nodesString)
			.write(to: url, atomically: true, encoding: .ascii)
	}
	
	convenience init(contentsOf url: URL) throws
	{
		let contents = try String(contentsOf: url)
		let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
		
		let dimensionSizes = lines.first!.components(separatedBy: ",").map { Int($0)! }
		
		let nodes = Progress(lines.dropFirst()).map { line -> SelfOrganizingMapNode in
			line.components(separatedBy: ",")
				.filter{ !$0.isEmpty }
				.map { Float($0)! }
		}
		
		self.init(nodes: nodes, dimensionSizes: dimensionSizes, distanceFunction: hexagonDistance(from: to: ))
	}
}

func hexagonDistance(from: [Int], to: [Int]) -> Float
{
	return Float(hexagonGridDistance(from: (column: from[0], row: from[1]), to: (column: to[0], row: to[1])))
}

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