# Generate a palette from improving color quality:
ffmpeg -i f.%04d.png -vf palettegen palette.png

# Generate GIF with provided palette:
ffmpeg -framerate 3 -i f.%04d.png -i palette.png -lavfi "paletteuse" -loop 0 -qscale:v 2 animation.gif
