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

import SOMKit
import MovieLensTools

// Create a group of commands: train and render

let group = Group { group in
    
    group.command(
        "train",
        Argument("map-width", description: "Width of the SOM", validator: Int.init(validatePositive: )),
        Argument("map-height", description: "Height of the SOM", validator: Int.init(validatePositive: )),
        Argument("epochs", description: "Number of epochs to train", validator: Int.init(validatePositive: )),
        Argument("dataset", description: "Path to the dataset file with which the map should be trained. The file must be in the format \"id1, feature1, ...\\nid2,...\"", validator: String.init(validateExisting: )),
        Argument<String>("o", description: "Save path for the self organizing map"),
        Option("nscale", 1, flag: nil, description: "Scale of neighbourhood", validator: Float.init(validatePositive: )),
        description: "Train a self organizing map on a given dataset"
    ) { mapWidth, mapHeight, epochs, movieTagsFilePath, mapFilePath, neighbourhoodScale in
        
        let movieTagsURL = URL(fileURLWithPath: movieTagsFilePath)
        let mapURL = URL(fileURLWithPath: mapFilePath)
        
        // Loading data
        
        print("Parsing movie tags...")
        let movieVectors = try GenomeParser.parseMovieVectors(at: movieTagsURL)
        print("Done. Beginning training...")
        
        // Creating and training map
        
        let map = SelfOrganizingMap(mapWidth, mapHeight, outputSize: movieVectors.first?.1.count ?? 0, distanceFunction: hexagonDistance(from: to: ))
        
        for epoch in Progress(0 ..< epochs)
        {
            map.update(with: movieVectors.random().1, totalIterations: epochs * 4 / 5, currentIteration: epoch, neighbourhoodScale: neighbourhoodScale)
        }
        
        // Saving map
        try map.write(to: mapURL)
        
    } // End command train
	
    group.command(
        "convert",
        Argument("scores", description: "Path to file containing dataset in the format \"id,featureID,featureValue\\n...\"", validator: String.init(validateExisting: )),
        Argument<String>("o", description: "Filepath to generated matrix file"),
        description: "Converts a 2d matrix from a 3 column CSV representation (id, featureID, value) to a matrix file"
    ) { scoresFilePath, outputFilePath in
        
        let scoresURL = URL(fileURLWithPath: scoresFilePath)
        let outputURL = URL(fileURLWithPath: outputFilePath)
        
        // Parse input CSV
        print("Parsing scores...")
        let scoreList = try GenomeParser.parseScores(at: scoresURL)
        
        print("Generating score matrix...")
        let scores = GenomeParser.generateGenomeScoreMatrix(from: scoreList)
        
        // Write output CSV
        print("Writing matrix...")
        try GenomeParser.write(scores.map{[$0.0] + $0.1}, to: outputURL)
        
    } // End command convert
}

group.run()
