function p = movieInit(p)

% Open movie file and retrieve basic info about movie:
[p.draw.movie.movieHandle, p.draw.movie.movieduration, ...
    p.draw.movie.fps, p.draw.movie.imgw, p.draw.movie.imgh, ~, ~, ...
    p.draw.movie.hdrStaticMetaData] = ...
    Screen('OpenMovie', p.draw.window, p.draw.movie.movieName, [], ...
    p.draw.movie.preloadsecs, [], p.draw.movie.pixelFormat, ...
    p.draw.movie.maxThreads, p.draw.movie.movieOptions);

% check to see if movie file width height will fit on the screen; if not,
% define a rectangle to draw it into:
if p.draw.movie.imgw > p.draw.screenRect(3) || ...
        p.draw.movie.imgh > p.draw.screenRect(4)
    
    % define rectanlge cuz movie too big
    p.draw.movie.dstRect = ...
        CenterRect((p.draw.screenRect(3) / p.draw.movie.imgw) * ...
        [0, 0, p.draw.movie.imgw, p.draw.movie.imgh], ...
        Screen('Rect', p.draw.window));
else
    % no rectangle needed, movie isn't too big
    p.draw.movie.dstRect = [];
end

% set current movie frame to 0; our approach will be to log the movie's
% time index at the end of a trial and start playback at that same index at
% the beginning of the subsequent trial; this means we will set the time
% index at the beginning of each trial before movie playback begins, so we
% need to set an initial value for that starting index.
p.draw.movie.movieIndex = p.draw.movie.movieIdxStart;

end