# average consecutive frames
# while preserving the framerate & total frame count
# => input & output at 30fps
ffmpeg -i input.mp4 -vf "tblend=average,framestep=2" -r 30 output.mp4

# this can be iterated: 4 frames are averaged
ffmpeg -i input.mp4 -vf "tblend=average,framerate=2,tblend=average,framerate=2" -r 30 output.mp4
