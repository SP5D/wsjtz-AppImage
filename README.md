# wsjtz-AppImage
AppImage of WSJT-Z – fork of WSJT-X with automation features.

Produced AppImage should work like a charm, but there is no guarantee.  
WSJTZ (and WSJTX) are surprisingly hard to pack into AppImage with all(!) dependencies.  
Tests have shown that I have provided enough libs for any real desktop, but feel free to lead me out of that error!

## Install
Just download and run the AppImage.

## Build
Clone the repo and:  
`docker-compose build; docker-compose up`  
You will get the AppImage in the `./release/` directory.
