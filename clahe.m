pkg load image;

% Custom function to clip the histogram
function clipped_hist = clip_histogram(hist, clip_limit)
  excess = sum(max(hist - clip_limit, 0)); % Calculate the excess pixels
  clipped_hist = min(hist, clip_limit);   % Clip the histogram
  redistribute = floor(excess / length(hist)); % Redistribute excess pixels
  clipped_hist += redistribute;
end

% Custom function to apply CLAHE
function result = clahe(image, clip_limit = 40, tile_grid_size = [8, 8])
  [height, width] = size(image); % Get the dimensions of the image
  tile_height = floor(height / tile_grid_size(1)); % Calculate the height of each tile
  tile_width = floor(width / tile_grid_size(2));  % Calculate the width of each tile
  
  % Initialize the result image and tile maps
  result = zeros(size(image));
  tile_map = zeros([tile_grid_size, 256]);
  
  % Calculate the histograms and CDFs for each tile
  for i = 0:tile_grid_size(1)-1
    for j = 0:tile_grid_size(2)-1
      y1 = i * tile_height + 1;
      y2 = (i + 1) * tile_height;
      x1 = j * tile_width + 1;
      x2 = (j + 1) * tile_width;
      
      % Handle edge cases where tiles may exceed image dimensions
      if (y2 > height)
        y2 = height;
      end
      if (x2 > width)
        x2 = width;
      end
      
      tile = image(y1:y2, x1:x2);
      
      % Calculate and clip the histogram
      hist = imhist(tile(:), 256);
      hist_clipped = clip_histogram(hist, clip_limit);
      
      % Calculate the CDF
      cdf = cumsum(hist_clipped);
      cdf = (cdf - min(cdf)) * 255 / (max(cdf) - min(cdf));
      cdf = round(cdf);
      
      % Store the CDF in the tile map
      tile_map(i+1, j+1, :) = cdf;
    end
  end
  
  % Apply bilinear interpolation to blend tiles
  for y = 1:height
    for x = 1:width
      % Find the tile indices
      i = floor((y - 1) / tile_height);
      j = floor((x - 1) / tile_width);
      
      % Handle edge cases for the last tiles
      if i >= tile_grid_size(1) - 1
        i = tile_grid_size(1) - 2;
      end
      if j >= tile_grid_size(2) - 1
        j = tile_grid_size(2) - 2;
      end
      
      % Relative positions within the tile
      y_rel = (y - i * tile_height) / tile_height;
      x_rel = (x - j * tile_width) / tile_width;
      
      % Interpolate the CDFs
      cdf = (1 - y_rel) * (1 - x_rel) * squeeze(tile_map(i+1, j+1, :)) + ...
            (1 - y_rel) * x_rel * squeeze(tile_map(i+1, j+2, :)) + ...
            y_rel * (1 - x_rel) * squeeze(tile_map(i+2, j+1, :)) + ...
            y_rel * x_rel * squeeze(tile_map(i+2, j+2, :));
      
      % Map the pixel value using the interpolated CDF
      result(y, x) = cdf(image(y, x) + 1);
    end
  end
  
  result = uint8(result); % Convert the result to uint8 format
end

% Load the image in grayscale
image = imread('xray.png');
if size(image, 3) == 3
  image = rgb2gray(image); % Convert to grayscale if the image is in RGB
end

% Apply the custom CLAHE function with a 8x8 grid
clahe_image = clahe(image, 40, [8 ,8]);

% Display the results
figure;
subplot(1, 2, 1);
imshow(image);
title('Original X-ray Image');

subplot(1, 2, 2);
imshow(clahe_image);
title('CLAHE Enhanced X-ray Image');
