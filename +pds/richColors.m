function colors = richColors

% define "main" colors
rgbValues = [...
    255 194 10; ...
    12 123 220; ...
    153 79 0; ...
    0 108 209; ...
    26 255 26; ...
    75 0 146; ...
    254 254 98; ...
    211 95 183; ...
    225 190 106; ...
    64 176 166; ...
    0 90 181; ...
    220 50 32; ...
    230 97 90; ...
    93 58 155; ...
    26 133 255; ...
    212 17 89; ...
    ];

% define "my" order
myOrder = [6; 14; 11; 4; 2; 15; 10; 5; 7; 9; 3; 1; 13; 12; 16; 8];

% reorder and return
colors = rgbValues(myOrder, :) / 255;