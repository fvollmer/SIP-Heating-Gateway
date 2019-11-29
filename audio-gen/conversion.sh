#!/bin/sh

# convert mp3 to sln and normalize

for f in *.mp3; do
    lame --decode $f;
done

for f in *.wav; do
    sox $f -t raw -r 8000 -b 16 -c 1 ${f%.wav}.sln --norm=-0.1
    rm $f
done
