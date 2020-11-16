# input: 30fps
# output: 60fps, half the duration
# PTS = presentation timestamp
ffmpeg -i input.mp4 -vf "setpts=0.5*PTS" -r 60 output.mp4
