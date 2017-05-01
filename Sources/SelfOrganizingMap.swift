//
//  SelfOrganizingMap.swift
//  SOMDemo
//
//  Created by Palle Klewitz on 15.02.17.
//  Copyright © 2017 Palle Klewitz. All rights reserved.
//

import Foundation
import Accelerate

typealias SelfOrganizingMapNode = [Float]
typealias Sample = [Float]

class SelfOrganizingMap
{
	let dimensionSizes:[Int]
	
	var dimensions: Int
	{
		return dimensionSizes.count
	}
	
	internal private(set) var nodes: [SelfOrganizingMapNode]
	
	private var temp: UnsafeMutablePointer<Float>
	private var nabla_0: Float
	
	init(_ dimensionSizes: Int..., outputSize: Int)
	{
		self.dimensionSizes = dimensionSizes
		self.nodes = (0 ..< dimensionSizes.reduce(1, *)).map{ _ in (0 ..< outputSize).map{_ in Float.random() * 2 - 1 }}
		self.temp = UnsafeMutablePointer<Float>.allocate(capacity: outputSize)
		self.nabla_0 = Float(self.dimensionSizes.max() ?? 1) / 2
	}
	
	deinit
	{
		temp.deallocate(capacity: self.nodes.first!.count)
	}
	
	final subscript(location: Int...) -> SelfOrganizingMapNode
	{
		return nodes[index(for: location)]
	}
	
	final func update(with sample: Sample, totalIterations: Int, currentIteration: Int)
	{
		guard let winningPrototypeIndex = nodes.minIndex(by: Array<Any>.compareDistance(sample)) else { return }
		let winningPrototypeCoordinates = coordinates(for: winningPrototypeIndex)
		
		let neighbourhood = generateNeighbourhood(of: winningPrototypeCoordinates, totalIterations: totalIterations, currentIteration: currentIteration)
		
//		var temp = Array<Float>(repeating: 0, count: self.nodes.first!.count)
		
		for index in self.nodes.indices
		{
//			for j in 0 ..< nodes[index].count
//			{
//				nodes[index][j] += neighbourhood[index] * (sample[j] - nodes[index][j])
//			}
			
			vDSP_vsub(nodes[index], 1, sample, 1, temp, 1, UInt(sample.count))
			vDSP_vsmul(temp, 1, [neighbourhood[index]], temp, 1, UInt(sample.count))
			vDSP_vadd(temp, 1, nodes[index], 1, temp, 1, UInt(sample.count))
			nodes[index] = Array(UnsafeBufferPointer(start: temp, count: sample.count))
			
		}
	}
	
	private final func coordinates(`for` index: Int) -> [Int]
	{
//		return dimensionSizes.reduce(([], index), { acc, size in (acc.0 + [acc.1 % size], acc.1 / size)}).0
		
		var result: [Int] = []
		result.reserveCapacity(dimensions)
		
		var idx = index
		
		for size in dimensionSizes
		{
			result.append(idx % size)
			idx = idx / size
		}
		
		return result
	}
	
	final func index(`for` location: [Int]) -> Int
	{
		precondition(location.count == dimensions, "Location coordinates must have same dimensionality as self organizing map.")
		return zip(location, dimensionSizes).reversed().reduce(0) { $0 * $1.1 + $1.0 }
	}
	
	private final func generateNeighbourhood(of: [Int], totalIterations: Int, currentIteration: Int) -> [Float]
	{
//		let nabla_0 = pow(Float(self.nodes.count), 1 / Float(self.dimensions))
//		let nabla_0 = Float(self.dimensionSizes.max() ?? 1) / 2
		let lambda = Float(totalIterations) / logf(nabla_0)
		let nabla = nabla_0 * expf(-Float(currentIteration) / lambda)
		let nabla_sq_2 = nabla * nabla * 2
		let alpha = expf(-Float(currentIteration) / lambda)
		
		let to = (column: of[0], row: of[1])
		
		var mask = nodes.indices.map { index -> Float in
			let coord = coordinates(for: index)
			return Float(hexagonGridDistance(from: (column: coord[0], row: coord[1]), to: to))
		}
		
//		return mask.map{expf(-$0 * $0 / nabla_sq_2) * alpha}
		
		vDSP_vsq(mask, 1, &mask, 1, UInt(mask.count))
		vDSP_vneg(mask, 1, &mask, 1, UInt(mask.count))
		vDSP_vsdiv(mask, 1, [nabla_sq_2], &mask, 1, UInt(mask.count))
		vvexpf(&mask, mask, [Int32(mask.count)])
		vDSP_vsmul(mask, 1, [alpha], &mask, 1, UInt(mask.count))
		
		return mask
	}
}
