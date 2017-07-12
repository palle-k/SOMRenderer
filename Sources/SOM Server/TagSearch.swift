//
//  Tagging.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 06.07.17.
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

import SOMKit
import MovieLensTools

enum MatchingMethod: String, Codable {
	case enclosedTags = "enclosed"
	case similarTags = "similar"
}

struct TagSimilarityRequest: Codable {
	let tags: Set<String>
	let matchingMethod: MatchingMethod
	let threshold: Float?
	let count: Int?
	
	private enum CodingKeys: String, CodingKey {
		case tags
		case matchingMethod = "method"
		case threshold
		case count
	}
}

struct MatchedTag: Codable {
	let tagName: String
	let score: Float
	
	private enum CodingKeys: String, CodingKey {
		case tagName = "tag"
		case score
	}
}

struct TagSimilarityResponse: Codable {
	let request: TagSimilarityRequest
	let matchedTags: [MatchedTag]
	
	private enum CodingKeys: String, CodingKey {
		case request
		case matchedTags = "matches"
	}
}

struct TagSearchEngine {
	var map: SelfOrganizingMap
	var tags: [String: Int]
	
	init(mapURL: URL, tagsURL: URL) throws {
		let map: SelfOrganizingMap
		let tags: [Int: String]
		
		do {
			print("Parsing map...")
			map = try SelfOrganizingMap(contentsOf: mapURL)
			print("Parsing tags...")
			tags = try GenomeParser.parseTags(at: tagsURL)
			
		} catch {
			fatalError("Could not parse map or tags")
		}
		
		print("Building index...")
		let tagNames = tags.map({ (element) -> (String, Int) in
			let (key, value) = element
			return (value, key - 1)
		})
		
		self.map = map
		self.tags = Dictionary(uniqueKeysWithValues: tagNames)
	}
	
	func similarTags(`for` request: TagSimilarityRequest) -> TagSimilarityResponse {
		// Compute a score for each tag based on its similarity to the tags in the request
		// A low score indicates a high similarity
		let scoredTags = tags.map { (tag) -> MatchedTag in
			let (key, index) = tag
			
			let tagScore = request.tags.flatMap({ self.tags[$0] }).reduce(0, { requestedTagAccumulatedScore, requestedTagIndex -> Float in
				
				let componentScore = self.map.nodes.reduce(0, { mapScore, node -> Float in
					
					switch request.matchingMethod {
					case .enclosedTags:
						return mapScore + max(node[index] - node[requestedTagIndex], 0) * max(node[index] - node[requestedTagIndex], 0)
						
					case .similarTags:
						return mapScore + (node[index] - node[requestedTagIndex]) * (node[index] - node[requestedTagIndex])
					}
					
				})
				
				return sqrt(componentScore)
			})
			
			
			return MatchedTag(tagName: key, score: tagScore)
		}
		
		// Filter tags by an optional threshold and remove tags already contained in the request
		let filteredTags:[MatchedTag]
		
		if let threshold = request.threshold {
			filteredTags = scoredTags.filter { tag -> Bool in
				tag.score <= threshold && !request.tags.contains(tag.tagName)
			}
		} else {
			filteredTags = scoredTags.filter { tag -> Bool in
				!request.tags.contains(tag.tagName)
			}
		}
		
		// Sort tags by their score from low score (high similarity) to high score (low similarity).
		let sortedTags = filteredTags.sorted(by: {
			$0.score < $1.score
		})
		
		// Limit the number of included results
		let result: [MatchedTag]
		if let count = request.count {
			result = Array(sortedTags.prefix(count))
		} else {
			result = sortedTags
		}
		
		// Generate response
		let response = TagSimilarityResponse(
			request: request,
			matchedTags: result
		)
		
		return response
	}
}
