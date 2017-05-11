# SOM Renderer

<img src="Maps.png" alt="Component Planes showing the distribution of SciFi, Cyborgs and Black and White movies" />

This Package contains the code used to generate visualizations of Kohonen Self-Organizing Maps
used on the MovieLens Dataset.

# Usage

## Installation

1. clone this repository.
2. cd into the cloned repository.
3. Build using `swift build --configuration release`.

## Usage

### Learn the dataset

The training subcommand expects 2 files:

1. The `genome-tags.csv` file from the MovieLens dataset
2. A file generated by joining movie names with `genome-scores.csv` in the form `movie1,score1,score2,...,scoreN\nmovie2,...`

```
./.build/release/SOMRenderer train <map-width> <map-height> <iterations> <genome-tags-filepath> <joined-movies-scores-filepath> <som-output-filepath> 
```

After training is finished, the SOM is written to the specified output location.

### Render the trained SOM

The visualization subcommand expects 3 files:

1. The SOM file generated in the training phase.
2. The `genome-tags.csv` file from the MovieLens dataset.
2. The file generated by joining movie names with `genome-scores.csv`.


```
./.build/release/SOMRenderer render <som-filepath> <genome-tags-filepath> <joined-movies-scores-filepath> <pdf-output-filepath>
```

This will render the U-Matrix showing the average distance between neighbouring tiles, each component plane and the distribution of data points into a PDF file.

# References

- F. Maxwell Harper and Joseph A. Konstan. 2015. The MovieLens Datasets: History and Context. ACM Transactions on Interactive Intelligent Systems (TiiS) 5, 4, Article 19 (December 2015), 19 pages. DOI=http://dx.doi.org/10.1145/2827872