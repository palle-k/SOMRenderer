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


import Accelerate
import Progress

public extension Array where Element == Float {
	
	/// Computes the squared euclidean distance between the vector `self` and the vector `to`.
	/// Both vectors must equal dimensionality
	///
	/// - Parameter to: Vector to which the distance should be computed
	/// - Returns: The squared euclidean distance between two vectors.
	public func distanceSq(to: [Element]) -> Element {
		precondition(self.count == to.count, "Vectors must have equal dimension.")
		var result: Float = 0
		vDSP_distancesq(self, 1, to, 1, &result, vDSP_Length(self.count))
		return result // * result
	}
	
	/// Computes the euclidean distance between the vector `self` and the vector `to`.
	/// Both vectors must equal dimensionality
	///
	/// - Parameter to: Vector to which the distance should be computed
	/// - Returns: The euclidean distance between two vectors.
	public func distance(to: [Element]) -> Float {
		return sqrt(self.distanceSq(to: to))
	}
	
	
	/// Returns a function which compares the euclidean distance of two input vectors
	/// to the distance of the vector `self`.
	///
	/// The returned function returns true, if the first input vector is closer to
	/// the vector `self` than the second input vector.
	///
	/// - Returns: A distance comparator function
	public func compareDistance() -> ([Float],[Float]) -> Bool {
		return { (_ first: [Float], _ second: [Float]) in
			return self.distanceSq(to: first) < self.distanceSq(to: second)
		}
	}
}

public extension Collection where Index == Int {
	
	/// Returns the index for the element which a comparator function determined to be the smallest.
	///
	/// - Parameter compare: Comparator function
	/// - Returns: Index of the smallest element in the collection
	/// - Throws: An error if the comparator function throws an error
	public func minIndex(by compare: @escaping (Element, Element) throws -> Bool) rethrows -> Int? {
		return try self.enumerated().min(by: {try compare($0.1, $1.1)})?.0
	}
	
	/// Returns the index for the element which a comparator function determined to be the biggest.
	///
	/// - Parameter compare: Comparator function
	/// - Returns: Index of the largest element in the collection
	/// - Throws: An error if the comparator function throws an error
	public func maxIndex(by compare: @escaping (Element, Element) throws -> Bool) rethrows -> Int? {
		return try self.enumerated().max(by: {try compare($0.1, $1.1)})?.0
	}
	
	/// Returns a randomly chosen element from the collection.
	///
	/// - Returns: A random element from the collection
	public func random() -> Element {
		return self[Int(arc4random_uniform(UInt32(self.count)))]
	}
}

public extension Collection where Element: Comparable, Index == Int {
	
	/// Returns the index of the smallest value of a collection of comparable elements
	///
	/// - Returns: Index of the smallest value
	public func minIndex() -> Int? {
		return self.minIndex(by: <)
	}
	
	/// Returns the index of the largest value of a collection of comparable elements
	///
	/// - Returns: Index of the largest value
	public func maxIndex() -> Int? {
		return self.maxIndex(by: <)
	}
}

public extension Float {
	
	/// Generates a random floating point number between 0 and 1.
	///
	/// - Returns: The random float number
	public static func random() -> Float {
		return Float(drand48())
	}
}

/// Computes the topological distance between two hexagons in
/// a hexagonal grid.
///
/// - Parameters:
///   - from: Index of the first hexagon
///   - to: Index of the second hexagon
/// - Returns: The topological distance between two hexagons.
public func hexagonGridDistance(from: (column: Int, row: Int), to: (column: Int, row: Int)) -> Int {
	// Based on http://www.redblobgames.com/grids/hexagons/
	/// Transforms hexagon coordinates into a cube coordinate system
	func toCubeCoordinates(point: (column: Int, row: Int)) -> (x: Int, y: Int, z: Int) {
		let x = point.column - (point.row + (point.row & 1)) / 2
		let z = point.row
		let y = -x - z
		return (x, y, z)
	}
	
	// Computes the distance between the two cube coordinates
	let fromCube = toCubeCoordinates(point: from)
	let toCube = toCubeCoordinates(point: to)
	
	return max(abs(fromCube.x - toCube.x), abs(fromCube.y - toCube.y), abs(fromCube.z - toCube.z))
}

public extension SelfOrganizingMap {
	
	/// Converts a SOM into a CSV string and writes it to a given location
	///
	/// - Parameter url: Location at which the CSV file should be written
	/// - Throws: An error if the file could not be written
	public func write(to url: URL) throws {
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
	
	/// Initializes a SOM from a CSV file at a given location
	///
	/// - Parameter url: Location of the CSV file
	/// - Throws: An error if the file could not be read or has an invalid format
	public convenience init(contentsOf url: URL) throws {
		let contents = try String(contentsOf: url)
		let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
		
		let dimensionSizes = try lines.first!.components(separatedBy: ",").map { dimensionString -> Int in
			
			guard let dimensionSize = Int(dimensionString) else {
				throw ParserError.invalidType(actual: dimensionString, expected: "Int")
			}
			return dimensionSize
		}
		
		let nodes = try Progress(lines.dropFirst()).map { line -> SelfOrganizingMapNode in
			try line.components(separatedBy: ",")
				.filter{ !$0.isEmpty }
				.map { valueString -> Float in
					
					guard let value = Float(valueString) else {
						throw ParserError.invalidType(actual: valueString, expected: "Float")
					}
					
					return value
				}
		}
		
		self.init(nodes: nodes, dimensionSizes: dimensionSizes, distanceFunction: hexagonDistance(from: to: ))
	}
}


/// Hexagon grid distance function which can be used on as a SOM distance function
///
/// - Parameters:
///   - from: From coordinate
///   - to: To coordinate
/// - Returns: Topological distance between the two coordinates
public func hexagonDistance(from: [Int], to: [Int]) -> Float {
	return Float(hexagonGridDistance(from: (column: from[0], row: from[1]), to: (column: to[0], row: to[1])))
}


/// Manhattan distance between two points
///
/// The Manhattan distance is defined as the sum of the differences
/// between the individual components of the input vectors.
///
/// - Parameters:
///   - from: Start point
///   - to: End point
/// - Returns: Manhattan distance between two points
public func manhattanDistance(from: [Int], to: [Int]) -> Float {
	return Float(zip(from, to).map(-).map(abs).reduce(0, +))
}

public func euclideanDistance(from: [Int], to: [Int]) -> Float {
	let distanceSquared = zip(from, to).map(-).map{$0 * $0}.reduce(0, +)
	return sqrt(Float(distanceSquared))
}

public func randomSquarePoint() -> Sample {
	return [Float.random(), Float.random()]
}

/// An error indicating that something had an invalid value or format
public struct ValidationError: Error, CustomStringConvertible {
	
	/// A description of the error which can be presented to the user
	public let description: String
	
	/// Creates a new validation error with a given description
	///
	/// - Parameter description: A description of the error for the user
	public init(description: String) {
		self.description = description
	}
}

public extension Int {
	
	/// Initializes an integer value and validates that it is greater than (not equal to or less than) zero.
	///
	/// - Parameter value: Value which should be validated
	public init(validatePositive value: Int) throws {
		guard value > 0 else {
			throw ValidationError(description: "Value \(value) expected to be positive.")
		}
		
		self = value
	}
}

public extension Float {
	public init(validatePositive value: Float) throws {
		guard value > 0 else {
			throw ValidationError(description: "Value \(value) expected to be positive.")
		}
		
		self = value
	}
}

public extension String {
	public init(validateExisting path: String) throws {
		guard FileManager.default.fileExists(atPath: path) else {
			throw ValidationError(description: "File \(path) does not exist.")
		}
		
		self = path
	}
}

public enum ParserError: Error
{
	case invalidType(actual: String, expected: String)
	case missingData(actual: String, expected: String)
}
