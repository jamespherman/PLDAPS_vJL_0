function v = smoothDiff(x)

% define filter coefficients
b = zeros(29,1);
b(1) =  -4.3353241e-04 * 2*pi;
b(2) =  -4.3492899e-04 * 2*pi;
b(3) =  -4.8506188e-04 * 2*pi;
b(4) =  -3.6747546e-04 * 2*pi;
b(5) =  -2.0984645e-05 * 2*pi;
b(6) =   5.7162272e-04 * 2*pi;
b(7) =   1.3669190e-03 * 2*pi;
b(8) =   2.2557429e-03 * 2*pi;
b(9) =   3.0795928e-03 * 2*pi;
b(10) =   3.6592020e-03 * 2*pi;
b(11) =   3.8369002e-03 * 2*pi;
b(12) =   3.5162346e-03 * 2*pi;
b(13) =   2.6923104e-03 * 2*pi;
b(14) =   1.4608032e-03 * 2*pi;
b(15) =   0.0;
b(16:29) = -b(14:-1:1);

[nr, nc] = size(x);
if nr == 1
    x = x(:);
    nData = nc;
else
    nData = nr;
end

% filter
vTemp = filter(b, 1, x(:))*1000;

% get rid of filtering-related transients at start & end
v = [zeros(14, 1); vTemp(15:nData, :); zeros(14,1)];

end