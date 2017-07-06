//
//  Tagging.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 06.07.17.
//

import Foundation

enum MatchingMethod: String, Codable {
	case enclosedTags = "enclosed"
	case similarTags = "similar"
}

struct TagSimilarityRequest: Codable {
	let tags: [String]
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
	let tag: String
	let score: Float
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
		let scoredTags = tags.map { (tag) -> MatchedTag in
			let (key, index) = tag
			
			let tagScore = request.tags.flatMap({ self.tags[$0] }).reduce(0, { (requestedTagAccumulatedScore, requestedTagIndex) -> Float in
				let componentScore = self.map.nodes.reduce(0, { (mapScore, node) -> Float in
					switch request.matchingMethod {
					case .enclosedTags:
						return mapScore + max(node[index] - node[requestedTagIndex], 0) * max(node[index] - node[requestedTagIndex], 0)
						
					case .similarTags:
						return mapScore + (node[index] - node[requestedTagIndex]) * (node[index] - node[requestedTagIndex])
					}
				})
				
				return sqrt(componentScore)
			})
			
			
			return MatchedTag(tag: key, score: tagScore)
		}
		
		let filteredTags:[MatchedTag]
		
		if let threshold = request.threshold {
			filteredTags = scoredTags.filter({ (tag) -> Bool in
				return tag.score <= threshold
			})
		} else {
			filteredTags = scoredTags
		}
		
		let sortedTags = filteredTags.sorted(by: {
			$0.score < $1.score
		})
		
		let result: [MatchedTag]
		
		if let count = request.count {
			result = Array(sortedTags.prefix(count))
		} else {
			result = sortedTags
		}
		
		let response = TagSimilarityResponse(
			request: request,
			matchedTags: Array(result)
		)
		
		return response
	}
}
