//
//  Utility.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 30.04.17.
//  Copyright © 2017 Palle Klewitz. All rights reserved.
//

import Foundation
import Accelerate

extension Array
{
	static func distanceSq(from: [Float], to: [Float]) -> Float
	{
		precondition(from.count == to.count, "Vectors must have equal dimension.")
		var result: Float = 0
		vDSP_distancesq(from, 1, to, 1, &result, vDSP_Length(from.count))
		return result
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
