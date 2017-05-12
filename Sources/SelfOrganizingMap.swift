//
//  SelfOrganizingMap.swift
//  SOMDemo
//
//  Created by Palle Klewitz on 15.02.17.
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


typealias SelfOrganizingMapNode = [Float]
typealias Sample = [Float]


/// A Kohonen Self-Organizing Map
///
/// A Self-Organizing Map is used to reduce dimensionality 
/// of a dataset while preserving topology.
class SelfOrganizingMap
{
	
	/// Topological size of the map.
	///
	/// If dimensionSizes == [10, 10], the map is a 2D grid consisting of 10 x 10 nodes.
	let dimensionSizes: [Int]
	
	
	/// Dimensions of the map.
	/// 
	/// If the map is a 2D grid, this value will be 2.
	var dimensions: Int
	{
		return dimensionSizes.count
	}
	
	
	/// Nodes of the map.
	///
	/// The nodes are row-major ordered.
	///
	/// Map coordinates can be transformed to array indices and vice versa using the
	/// `index(for: )` and `coordinates(for: )` functions.
	private(set) var nodes: [SelfOrganizingMapNode]
	
	
	/// Function determining the distance between two nodes based on their indices on the map.
	///
	/// This may be the Euclidean distance or the distance on a hexagonal grid.
	var distanceFunction: ([Int], [Int]) -> Float
	
	
	/// Buffer used as temporary store for vectorized operations on nodes
	private var temp: UnsafeMutablePointer<Float>
	
	
	/// Factor determining the size of the neighbourhood based on the map size
	private var nabla_0: Float
	
	
	/// Creates a new Self-Organizing Map using existing vectors, a distance function and dimension sizes
	///
	/// - Parameters:
	///   - nodes: Node vectors
	///   - dimensionSizes: Topological size of the map
	///   - distanceFunction: Function determining the distance between nodes during training.
	init(nodes: [SelfOrganizingMapNode], dimensionSizes: [Int], distanceFunction: @escaping ([Int], [Int]) -> Float)
	{
		self.nodes = nodes
		self.temp = UnsafeMutablePointer<Float>.allocate(capacity: self.nodes.first?.count ?? 0)
		self.dimensionSizes = dimensionSizes
		self.nabla_0 = Float(self.dimensionSizes.max() ?? 1) / 2
		self.distanceFunction = distanceFunction
	}
	
	
	/// Creates a new randomly initialized Self-Organizing Map using the given topological size and output size
	///
	/// - Parameters:
	///   - dimensionSizes: Topological size of the map
	///   - outputSize: Dimensionality of node vectors of the map.
	///   - distanceFunction: Function determining the distance between nodes during training.
	init(_ dimensionSizes: Int..., outputSize: Int, distanceFunction: @escaping ([Int], [Int]) -> Float)
	{
		self.dimensionSizes = dimensionSizes
		self.nodes = (0 ..< dimensionSizes.reduce(1, *)).map{ _ in (0 ..< outputSize).map{_ in Float.random() * 2 - 1 }}
		self.temp = UnsafeMutablePointer<Float>.allocate(capacity: outputSize)
		self.nabla_0 = Float(self.dimensionSizes.max() ?? 1) / 2
		self.distanceFunction = distanceFunction
	}
	
	
	deinit
	{
		temp.deallocate(capacity: self.nodes.first!.count)
	}
	
	
	/// Retrieves a node based on its location on the map
	///
	/// - Parameter location: Location of the node
	/// - Returns: The node at the given location
	final subscript(location: Int...) -> SelfOrganizingMapNode
	{
		return nodes[index(for: location)]
	}
	
	
	/// Performs an update of the map based on the given sample.
	///
	/// The closest node to the sample and neighbouring nodes will be moved towards this sample.
	///
	/// The winning node is determined using the euclidean distance between node vectors and the sample vector.
	///
	/// The strength of indirect updates is exponentially decaying relative to the distance determined by the topological distance function.
	///
	/// - Parameters:
	///   - sample: Sample towards which the map should be adjusted.
	///   - totalIterations: Total number of iterations the map will be trained
	///   - currentIteration: Current training iteration. The neighbourhood size and training rate will be smaller for later iterations.
	///   - neighbourhoodScale: Scale applied to the neighbourhood.
	final func update(with sample: Sample, totalIterations: Int, currentIteration: Int, neighbourhoodScale: Float)
	{
		// determine Best Matching Unit
		guard let winningPrototypeIndex = nodes.minIndex(by: Array<Any>.compareDistance(sample)) else { return }
		let winningPrototypeCoordinates = coordinates(for: winningPrototypeIndex)
		
		// Calculating neighbourhood scaling factors
		let neighbourhood = generateNeighbourhood(of: winningPrototypeCoordinates, totalIterations: totalIterations, currentIteration: currentIteration, neighbourhoodScale: neighbourhoodScale)
		
		// Performing update
		for index in self.nodes.indices
		{
			vDSP_vsub(nodes[index], 1, sample, 1, temp, 1, vDSP_Length(sample.count))
			vDSP_vsmul(temp, 1, [neighbourhood[index]], temp, 1, vDSP_Length(sample.count))
			vDSP_vadd(temp, 1, nodes[index], 1, temp, 1, vDSP_Length(sample.count))
			nodes[index] = Array(UnsafeBufferPointer(start: temp, count: sample.count))
			
		}
	}
	
	
	/// Transforms an index for the node array to a location in map coordinates.
	///
	/// - Parameter index: Node array index
	/// - Returns: Location in map coordinates
	final func coordinates(`for` index: Int) -> [Int]
	{
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
	
	
	/// Transforms a location on the map to an index for the node array
	///
	/// - Parameter location: Location on the map
	/// - Returns: Index for the node array
	final func index(`for` location: [Int]) -> Int
	{
		precondition(location.count == dimensions, "Location coordinates must have same dimensionality as self organizing map.")
		return zip(location, dimensionSizes).reversed().reduce(0) { $0 * $1.1 + $1.0 }
	}
	
	
	/// Generates an array of scaling values based on the neighbourhood function.
	///
	/// - Parameters:
	///   - of: Best matching unit
	///   - totalIterations: Total number of training iterations.
	///   - currentIteration: Current training iteration. The neighbourhood size and learning rate will be smaller for later iterations.
	///   - neighbourhoodScale: Scale applied to the neighbourhood size.
	/// - Returns: Scaling values for each node determining how much the node should be updated.
	private final func generateNeighbourhood(of: [Int], totalIterations: Int, currentIteration: Int, neighbourhoodScale: Float) -> [Float]
	{
//		let nabla_0 = pow(Float(self.nodes.count), 1 / Float(self.dimensions))
//		let nabla_0 = Float(self.dimensionSizes.max() ?? 1) / 2
		
		// Calculating size of neighbourhood
		
		let lambda = Float(totalIterations) / logf(nabla_0)
		let nabla = nabla_0 * expf(-Float(currentIteration) / lambda)
		let nabla_sq_2 = nabla * nabla * 2 * neighbourhoodScale
		
		// Calculating learning rate
		
		let alpha = expf(-Float(currentIteration) / lambda)
		
		// Calculating factor for every index of the SOM:
		// scale(i,j)= exp(-(dist(i,j)^2) / nabla_sq_2) * alpha
		
		var mask = nodes.indices.map { index -> Float in
			let coord = coordinates(for: index)
			return self.distanceFunction(of, coord)
		}
		
		vDSP_vsq(mask, 1, &mask, 1, vDSP_Length(mask.count))
		vDSP_vneg(mask, 1, &mask, 1, vDSP_Length(mask.count))
		vDSP_vsdiv(mask, 1, [nabla_sq_2], &mask, 1, vDSP_Length(mask.count))
		vvexpf(&mask, mask, [Int32(mask.count)])
		vDSP_vsmul(mask, 1, [alpha], &mask, 1, vDSP_Length(mask.count))
		
		return mask
	}
	
}
