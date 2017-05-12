function [ImgTextures, ImgFiles] = GetImage(params)
% createImageList creates a series of image textures in random orders
% Image is a cell array:1xN, N = # of Image Classes
% each cell array contains a 4-D matrix, Y pixels x X pixels x RGC x # of
% Images per Class
% 
% IMAGES SHOULD BE LOCATED IN IMAGE FOLDER
% Images for PFO Localizer are under copyright: You can use your own images
% of 80 scenes and buildings, 80 face images, 80 object images isolated fro
% backgroud, and 80 scrambled objects generated from 80 object images
%
% Heeyoung Choo 4/27/2017 UIUC
% CC By 4.0

% declare variables
ImgTextures = {};
ImgFiles = [];
Image = zeros(params.Img_Size,params.Img_Size,3,max(params.Stim_Num));

for t = 1:length(params.Stim_Type)
    % get file info
    ImgFileNames = dir([params.Stim_Dir filesep params.Stim_Type{t} '*']);
    
    % how many images should we pick?
    if length(params.Stim_Num) > 1
        Stim_Num = params.Stim_Num(t);
    else
        Stim_Num = params.Stim_Num;
    end
    % randomly pick from available images
    ImgPick = randperm(length(ImgFileNames),Stim_Num);
    
    % store image matrices and image file names
    for img = 1:Stim_Num
        Image(:,:,:,img) = imread([params.Stim_Dir filesep ImgFileNames(ImgPick(img)).name]);
        ImgFiles{t,img} = [params.Stim_Dir filesep,ImgFileNames(ImgPick(img)).name];
    end
    
    % store image matrices of each class
    ImgTextures{t} = Image;
end
