% JUSAL - Computes a Joint Upsampled Random Color Difference Map
%                                                                       
% SMAP = JUSAL(I, D, B, N_R) computes a saliency map by joint upsampling a
% random color difference map. Low values of downsize scale (D) and random
% sample size (N_R) reduce execution time, at the expense of, possibly, 
% decreasing accuracy. Positive boundary ratio values (B) smaller than 0.5
% leverage boundary prior and improve accuracy. Adopting B = 0.5 sets the
% entire image as boundary and is equivalent to disabling boundary prior.
%
% Parameters:                                                             
%   I  uint8 RGB input image;                                            
%   D  downsize scale (]0.0, 1.0]);
%   B  boundary ratio (]0.0, 0.5]);
%   N  random sample size ([1, inf[);
%
% Example:
%   I = imread('peppers.png');
%   S = JUSAL(I, 0.25, 0.2, 3);
%   figure; imshow(I); figure; imshow(S)

% THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT ANY EXPRESSED OR IMPLIED 
% WARRANTIES OF ANY KIND, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
% MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
% IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
% CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
% TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THIS 
% SOFTWARE OR THE USE OR OTHER DEALINGS IN THIS SOFTWARE.
%
% Author: Maiko Lie <minian.lie@gmail.com>
% Last revision: Nov 3, 2016  

function SMAP = JUSAL(I, D, B, N_R)
    input = im2double(I);
    [rows, cols, ~] = size(I);
       
    %-------------------------------------------+
    % Downscale and convert from RGB to CIELab. |
    %-------------------------------------------+
    input_scaled = imresize(input, D); 
    [s_rows, s_cols, ~] = size(input_scaled);

    color_transf = makecform('srgb2lab');
    input_scaled = applycform(input_scaled, color_transf);
    
    L = input_scaled(:, :, 1);
    a = input_scaled(:, :, 2);
    b = input_scaled(:, :, 3);
    
    %----------------------------------------------------+
    % Define set of boundary pixels for random sampling. |
    %----------------------------------------------------+
    boundary_left  = 1:(1 + round(B*s_cols));
    boundary_right = (s_cols - round(B*s_cols)):s_cols;
    boundary_upper = 1:(1 + round(B*s_rows));
    boundary_lower = (s_rows - round(B*s_rows)):s_rows;
    boundary_cols  = [boundary_left  boundary_right];
    boundary_rows  = [boundary_upper boundary_lower];
    
    ismap = zeros(s_rows, s_cols);
    
    %--------------------------------------+
    % Compute random color difference map. |
    %--------------------------------------+
    for t = 1:N_R;
        L_vec  = L(:);
        a_vec  = a(:);
        b_vec  = b(:);
        
        %--------------------------------+
        % Sample random boundary pixels. |
        %--------------------------------+
        ran    = randi(length(boundary_cols), 1, length(L_vec));
        x_r    = boundary_cols(ran);
        ran    = randi(length(boundary_rows), 1, length(L_vec));
        y_r    = boundary_rows(ran);
        index  = sub2ind([s_rows s_cols], y_r, x_r);
        
        L_rand = reshape(L_vec(index), size(L));
        a_rand = reshape(a_vec(index), size(a));
        b_rand = reshape(b_vec(index), size(b));

        %----------------------------+
        % Compute color differences. |
        %----------------------------+
        L_dissim = abs(L - L_rand);
        a_dissim = abs(a - a_rand);
        b_dissim = abs(b - b_rand);
        ismap = ismap + sqrt(L_dissim.^2 + a_dissim.^2 + b_dissim.^2);
    end
    ismap = mat2gray(ismap);
    ismap = imresize(ismap, [rows cols]);
    
    %---------------------------------------------------------------+
    % Apply Fast Global Smoothing on the intermediary saliency map, |
    % using the full-resolution RGB input as guide image.           |
    %---------------------------------------------------------------+
    SMAP = mexFGS(ismap, double(I), 0.03, 10^2, 3, 0.5);
    
    %-------------------------------------+
    % Gamma correction and normalization. |
    %-------------------------------------+
    SMAP = imadjust(SMAP, [], [], 3);
    SMAP = mat2gray(SMAP);
end