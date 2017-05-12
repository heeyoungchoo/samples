function FPOLocalizer
% FPOLocalizer.m
%
% Traslated (only functionally) from Dirk's python FPOLocalizer
% One difference from Dirk's codes is that 
% repetitions are initially generated with 16.7% chance instead of 25%. 
% This change was made to evenly distribute repetitions within each miniblock.
%
% Below functions are borrowed from 
% https://figshare.com/articles/Data_amp_materials_for_Moutsiana_et_al_unpublished_/1579442, 
% 
%   SetupRand.m
%   SetupKeyCodes.m
%   CurrentSession.m
%   new_line.m
% 
% To properly executed, you need 80 images per image categories, scenes and
% buildings, faces, objects, and scrambled objects under image folder
%
% 4/27/2017 Heeyoung Choo UIUC
% CC BY 4.0

%% Initialize
clc; sca;

Subj_ID = input('Subject ID (If # not provided, run in emul mode):  ');
if isempty(Subj_ID)     % if no number is given, emulate 1 run
    Emul = true;
    Subj_ID = 9999;
    NumRuns = 1;
else
    Emul = false;   
    NumRuns = input('How Many Runs? :  ');
    if isempty(NumRuns)
        NumRuns = 2;    % default run number is 2
    end
end

%% Engine parameters
Parameters = struct;                
Parameters.Emul = Emul;

%% Scanner parameters
Parameters.TR = 2;   
Parameters.DummieVolumes = 3;   % Is yours too?

%% Subject & session
Parameters.Subj_ID = [sprintf('%04.0f%',Subj_ID),'HC'];   % Load subject details
Parameters.Exp_ID = 'FPOLocalizer'; % Experiment code
Parameters.Instruction = ['You will see a series of photos and jumbled up photos.\n\n' ...
    'Your task is to press a button when you see the same image appear twice in a row. \n\n', ...
    'Please keep your eyes fixated at the cross in the center of the screen\n\n\n'];

%% Experimental Parameters
Parameters.NumRuns = NumRuns;
Parameters.Stim_Num = 80;       % how many images per class do you use?
Parameters.Stim_Dir = 'images';
Parameters.Stim_Type = {'face','place','object','scrambled'};

% Block Order: odd run = 1, even run = 2
Parameters.MiniBlockSequence(:,:,1) = {'scrambled','object','place','face'; ...
    'face','place','object','scrambled'; ...
    'object','face','scrambled','place'; ...
    'place','scrambled','object','face'; ...
    'scrambled','face','object','place'};
Parameters.MiniBlockSequence(:,:,2) = {'object','scrambled','face','place'; ...
    'scrambled','face','place','object'; ...
    'place','object','face','scrambled'; ...
    'place','scrambled','object','face'; ...
    'object','face','place','scrambled'};

Parameters.Block_Num = size(Parameters.MiniBlockSequence,1);
Parameters.MiniBlock_Num = size(Parameters.MiniBlockSequence,2);

% Time Parameters
if Emul % if emulation, let's get over with it quickly
    Parameters.Preblock_Duration = 2;
    Parameters.Interblock_Duration = 2;
    Parameters.Postblock_Duration = 2;
else
    Parameters.Preblock_Duration = 12;
    Parameters.Interblock_Duration = 12;
    Parameters.Postblock_Duration = 12;
end

Parameters.Block_Duration = 72;
Parameters.MiniBlock_Duration =  Parameters.Block_Duration / Parameters.MiniBlock_Num;
Parameters.Stim_Duration = 0.5;
Parameters.ISI = 0.5;

Parameters.Run_Duration = Parameters.Preblock_Duration + ...
    Parameters.Block_Duration * size(Parameters.MiniBlockSequence,1) + ...
    Parameters.Interblock_Duration * (size(Parameters.MiniBlockSequence,1) - 1) + ...
    Parameters.Postblock_Duration;

% how many repetitions in a miniblock?
Parameters.Event_Num_per_MiniBlock = 2;

% how many images are "used" in a miniblock?
Parameters.Stim_Num_per_MiniBlock = Parameters.MiniBlock_Duration / ...
    (Parameters.Stim_Duration + Parameters.ISI) - ...
    Parameters.Event_Num_per_MiniBlock * (Parameters.Stim_Duration + Parameters.ISI); 

% how many images are "presented" in a miniblock? (sorry about the inconsistency)
Parameters.Stim_Num_per_Block = (Parameters.Stim_Num_per_MiniBlock + Parameters.Event_Num_per_MiniBlock) ...
    * numel(Parameters.Stim_Type); 

% Screen Parameters.
Parameters.Screen  = 0;   
Parameters.Resolution = [0,0,1024,786];
Parameters.Foreground = [0 0 0];            
Parameters.Background = [127 127 127];      
Parameters.Img_Size = 400;
Parameters.Stim_Size = 640;
Parameters.Fixation_Size = [24,0];                    
Parameters.Fixation_Width = 4;                                          
Parameters.Fixation_Color = Parameters.Foreground;
Parameters.FontSize = 20;                   
Parameters.FontName = 'Calibri';

%% Initialize PTB
if Parameters.Emul % do not fill the whole screen, no hide curser, no mute command window input
    [Win, Rect] = Screen('OpenWindow', Parameters.Screen, Parameters.Background,Parameters.Resolution);
    Screen('BlendFunction', Win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
else 
    [Win, Rect] = Screen('OpenWindow', Parameters.Screen, Parameters.Background);
    Screen('BlendFunction', Win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Parameters.Resolution = Rect;
    HideCursor;
    ListenChar(2);
end
Screen('TextFont', Win, Parameters.FontName);
Screen('TextSize', Win, Parameters.FontSize);
Parameters.RefreshDur = Screen('GetFlipInterval',Win);
Parameters.Rect = Parameters.Resolution;

%% Run the experiment
QuitExp = false;
CurrentRun = 1;
Parameters.Is_Aborted = false;
while ~QuitExp
    if CurrentRun > NumRuns % all runs done?
        QuitExp = true;
    else % run a run!
        [Parameters.Session, Parameters.Session_name] = CurrentSession([Parameters.Subj_ID '_' date '_' Parameters.Exp_ID]);   % session number?
        Parameters.Stim_Sequence = Parameters.MiniBlockSequence(:,:,mod(Parameters.Session -1,2)+1); % block order?
        Parameters.Is_Aborted = ShowImage(Win,Parameters);  % show show show
        CurrentRun = CurrentRun+1;
    end
    if Parameters.Is_Aborted % if esc key pressed
        QuitExp = true; % quit experiment
    end
end

%% Farewell screen
Screen('FillRect', Win, Parameters.Background, Parameters.Rect);
if Parameters.Is_Aborted
    DrawFormattedText(Win, 'Experiment was aborted mid-experiment!', 'center', 'center', Parameters.Foreground);
else
    DrawFormattedText(Win, 'Thank you!', 'center', 'center', Parameters.Foreground);
end
Screen('Flip', Win);
WaitSecs(2.0);
ShowCursor;
Screen('CloseAll');

if ~Parameters.Emul %don't forget to bring the cursor back and to enable command input!
    ShowCursor;
    ListenChar(0);
end
