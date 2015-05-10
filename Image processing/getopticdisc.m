function [opticDiscMask] = getopticdisc (retinaRGB, closingThresholdValue, opticDiscDilationSize)
    %% Get intensity
    subplot(1, 2, 1), imshow(retinaRGB); title('RGB');
    I = double(retinaRGB) / 255;
    I = sum(I, 3) ./ 3;
    subplot(1, 2, 2), imshow(I); title('Intensity');

    %% Median filter on intensity channel
    subplot(1, 2, 1), imshow(I); title('Before median filter');
    I = medfilt2(I);
    subplot(1, 2, 2), imshow(I); title('Median filter on intensity');

    %% Histogram equalization
    subplot(1, 2, 1), imshow(I); title('Before histogram equalization');
    I = adapthisteq(I);
    subplot(1, 2, 2), imshow(I); title('Histogram equalization');

    %% Remove vessels by grayscale closing
    subplot(1, 2, 1), imshow(I); title('Before grayscale closing');
    se = strel('disk', 8);
    closeI = imclose(I, se);
    subplot(1, 2, 2), imshow(closeI); title('Grayscale closing');

    %% Threshold image to create mask
    subplot(1, 2, 1), imshow(closeI); title('Before threshold');
    maskFirst = im2bw(closeI, closingThresholdValue);  % Something to do with this hardcoded value
    subplot(1, 2, 2), imshow(maskFirst); title('Mask');

    %% Overlay mask on the original image
    subplot(1, 2, 1), imshow(I); title('Before overlay');
    maskFirstRev = imcomplement(maskFirst);
    marker = I .* maskFirstRev;
    subplot(1, 2, 2), imshow(marker); title('Overlay');

    %% Reconstruction
    subplot(1, 2, 1), imshow(marker); title('Before reconstruction');
    reconstructed = imreconstruct(marker, I);
    subplot(1, 2, 2), imshow(reconstructed); title('Reconstruction');

    %% Threshold on image differences and dilate to remove vessels
    diff = I - reconstructed;
    subplot(1, 2, 1), imshow(diff, []), title('Difference before threshold and dilation');
    level = graythresh(diff);
    opticDiscMask = im2bw(diff, level);
    se = strel('disk', opticDiscDilationSize);
    opticDiscMask = imdilate(opticDiscMask, se);
    subplot(1, 2, 2), imshow(opticDiscMask), title('Mask');

    %% Select optic disc and dilate to make sure it's big enough
    subplot(1, 2, 1), imshow(retinaRGB), title('Before optic disc choice');
    % Get labels and measurement
    labeledDiscMask = bwlabel(opticDiscMask);
    measurements = regionprops(opticDiscMask, 'Area', 'Perimeter');
    % Calculate circularities
    allAreas = [measurements.Area];
    allPerimeters = [measurements.Perimeter];
    allCircularities = (4 * pi * allAreas) ./ allPerimeters .^ 2;
    allCircularities(~isfinite(allCircularities)) = 0;
    % Calculate scores
    allScores = allCircularities .* allAreas;
    % Create image with optic disc
    [M, Ind] = max(allScores);
    % Mask not found work around
    if (size(Ind) == 0)
        Ind = 1;
    end
    [r, c] = find(labeledDiscMask == Ind);
    Ind = sub2ind(size(labeledDiscMask), r, c);
    opticDiscMask = zeros(size(opticDiscMask));
    opticDiscMask(Ind) = 1;
    % Dilation
    se = strel('disk', 6);
    opticDiscMask = imdilate(opticDiscMask, se);
    subplot(1, 2, 2), imshow(I .* imcomplement(opticDiscMask)), title('Optic disc extracted');
end