function [Is_Aborted] = ShowImage(Win,Parameters)
% ShowImage(Parameters) runs a FPO localizer run. It returns "true" if a
% run is aborted in the middle of the run by pressing the ESC key. It
% retures false if the entire run is fully completed. Sorry about the cognitively
% incompatible labeling. I just realized this after writing this whole
% thing up.
% 
% Heeyoung Choo 4/27/2017 UIUC
% CC BY 4.0

%% Create the mandatory folders if not already present
if ~exist([cd filesep 'Results'], 'dir')
    mkdir('Results');
end

%% Initialize randomness & keycodes
SetupRand;
SetupKeyCodes;

%% Imagelist
% give a warning!
Screen('FillRect', Win, Parameters.Background, Parameters.Rect);
DrawFormattedText(Win, 'Please stand by while images are loading...', 'center', 'center', Parameters.Foreground);
Screen('Flip', Win);

% get image matrices and file names
[Parameters.Stimulus, Parameters.Stim_FileName] = GetImage(Parameters);

% make image textures
ImageTex = [];
for cond = 1:length(Parameters.Stim_Type)
    for f = 1:size(Parameters.Stimulus{1}, 4)
        ImageTex(cond,f) = Screen('MakeTexture', Win, Parameters.Stimulus{cond}(:,:,:,f));
    end
end

% make a imagelist of the run
Events = [];
Conds = [];
Imgs = [];
for b = 1:Parameters.Block_Num
    for m = 1:Parameters.MiniBlock_Num
        rep_counter = 0;
        for i = 1:Parameters.Stim_Num_per_MiniBlock
            cond = find(strcmp(Parameters.Stim_Type,Parameters.Stim_Sequence(b,m)));
            img = (b-1)*Parameters.Stim_Num_per_MiniBlock + i;
            if rep_counter < Parameters.Event_Num_per_MiniBlock   % make an events
                if (randperm(6,1) == 1) || (i > Parameters.Stim_Num_per_MiniBlock - 2) % Dirk's orignal: randperm(4,1) == 2
                    Conds = [Conds;cond;cond];
                    Imgs = [Imgs;img;img];
                    Events = [Events;0;1];
                    rep_counter = rep_counter + 1;
                else
                    Conds = [Conds;cond];
                    Imgs = [Imgs;img];
                    Events = [Events;0];
                end
            else
                Conds = [Conds;cond];
                Imgs = [Imgs;img];
                Events = [Events;0];
            end
        end
    end
end
ImgList = [Conds,Imgs]; % (16+2)*4*5 = 360 images displayed in total!

%% Placeholders 
Results = [];

TrialOutput = struct;
TrialOnset = [];
TrialImage = {};

Behaviour = struct;
Behaviour.Response = [];
Behaviour.ResponseTime = [];

EventTimeStamps = [];

%% Preset the session
Start_of_Expmt = -1;
Is_Aborted = Parameters.Is_Aborted;

%% Screen coordinates
% fixtaion
[CenterX, CenterY] = RectCenter(Parameters.Rect);
Fixation_XY = [-Parameters.Fixation_Size(1)./2 Parameters.Fixation_Size(1)./2 0 0; ...
    0 0 -Parameters.Fixation_Size(1)./2 Parameters.Fixation_Size(1)./2];
Fixation_Rect = CenterRectOnPointd([0 0 Parameters.Fixation_Size(1) Parameters.Fixation_Width; ...
    0 0 Parameters.Fixation_Width Parameters.Fixation_Size(1)],CenterX,CenterY);

% stimulus
StimRect = [0 0 repmat(size(Parameters.Stimulus{1},1), 1, 2)];
StimRectOnMain = CenterRectOnPointd([0 0 Parameters.Stim_Size Parameters.Stim_Size],CenterX,CenterY);

%% Standby screen
if Parameters.Emul
    % emul scanner
    TrigStr = 'Press any key to start...'; 
    Volumes_to_Seconds = Parameters.Run_Duration;
else
    % real scanner
    TrigStr = 'Stand by for scan...';    % trigger string = or ^
    Volumes_to_Seconds = (Parameters.Run_Duration + Parameters.DummieVolumes*Parameters.TR);    % add dummie volumes
end
disp(['Duration: ',num2str(floor(Volumes_to_Seconds/60)),' minutes and ',num2str(mod(Volumes_to_Seconds,60)) ' seconds']);

% show instructions
Screen('FillRect', Win, Parameters.Background, Parameters.Rect);
if num2str(Parameters.Session) > num2str(Parameters.NumRuns)
    DrawFormattedText(Win, [Parameters.Instruction TrigStr ...
        '\n \n' num2str(Parameters.Session) ' out of total ' num2str(Parameters.NumRuns + Parameters.Session - 1) ' runs' ...
        '\n \n \n (Duration: ',num2str(floor(Volumes_to_Seconds/60)),' minutes and ',num2str(mod(Volumes_to_Seconds,60)) ' seconds)'], ...
        'center', 'center', Parameters.Foreground);
else
    DrawFormattedText(Win, [Parameters.Instruction TrigStr ...
        '\n \n' num2str(Parameters.Session) ' out of total ' num2str(Parameters.NumRuns) ' runs' ...
        '\n \n \n (Duration: ',num2str(floor(Volumes_to_Seconds/60)),' minutes and ',num2str(mod(Volumes_to_Seconds,60)) ' seconds)'], ...
        'center', 'center', Parameters.Foreground);
end
Screen('Flip', Win);

% wait for a trigger
Key = zeros(1,256);
if Parameters.Emul
    WaitSecs(0.1);
    KbWait(-1);
    [Keypr Start_of_Expmt Key] = KbCheck(-1);
else
    WaitSecs(0.1);
    Go = false;
    while ~Go
        [Keypr Time Key] = KbCheck(-1);
        if sum(Key(KeyCodes.Trigger)) % escape if triggered
            Go = true;
        elseif Key(KeyCodes.Escape) % escape if aborted
            Is_Aborted = true;  % aborted!
            Go = true;
        else
            Go = false;
        end
    end
    Key = zeros(1,256);
end

% toggle this when key was pressed recently
k = false;

% Toggle this when trial was logged
t_on = false;   t_off = true;

% Toggle this when trial was repeated
is_event = false;

% update current time
Start_of_Expmt = GetSecs;
RUN_DONE = false;
while ~RUN_DONE % until done
    if Is_Aborted % if aborted
        RUN_DONE = true; % done
    end
    
    % time check!
    elapsedSec = GetSecs - Start_of_Expmt;
    imageTime = (Parameters.Stim_Duration + Parameters.ISI);
    totalBlockTime = Parameters.Block_Duration * Parameters.Block_Num + Parameters.Interblock_Duration * (Parameters.Block_Num - 1);
    
    % inital fixation block
    if elapsedSec < Parameters.Preblock_Duration
        % Draw fixation cross; stroked
        Screen('FillRect', Win, Parameters.Fixation_Color,Fixation_Rect(1,:));
        Screen('FillRect', Win, Parameters.Fixation_Color, Fixation_Rect(2,:));
        Screen('FillRect', Win, [255 255 255]-Parameters.Fixation_Color, InsetRect(Fixation_Rect(1,:),round(Parameters.Fixation_Width./3),round(Parameters.Fixation_Width./3)));
        Screen('FillRect', Win, [255 255 255]-Parameters.Fixation_Color, InsetRect(Fixation_Rect(2,:),round(Parameters.Fixation_Width./3),round(Parameters.Fixation_Width./3)));
        % Flip screen
        Screen('Flip', Win);
    
    % during block + interblock fixation
    elseif elapsedSec < (Parameters.Preblock_Duration + totalBlockTime)        
        % which block?
        blockIdx = floor((elapsedSec - Parameters.Preblock_Duration) ./ (Parameters.Block_Duration + Parameters.Interblock_Duration)) + 1;
        elapsedBlockTime = mod(elapsedSec - Parameters.Preblock_Duration, Parameters.Block_Duration + Parameters.Interblock_Duration);
        if elapsedBlockTime < Parameters.Block_Duration     % during block
            % get image index and get event index
            ImgIdx = ImgList((blockIdx - 1) * Parameters.Stim_Num_per_Block + floor(elapsedBlockTime/imageTime) + 1,:);
            is_event = Events((blockIdx - 1) * Parameters.Stim_Num_per_Block + floor(elapsedBlockTime/imageTime) + 1);
            if mod(elapsedBlockTime,imageTime) < Parameters.Stim_Duration % image
                % draw image
                Screen('DrawTexture', Win, ImageTex(ImgIdx(1,1),ImgIdx(1,2)), StimRect, StimRectOnMain);
                % draw fixation cross
                Screen('FillRect', Win, Parameters.Fixation_Color,Fixation_Rect(1,:));
                Screen('FillRect', Win, Parameters.Fixation_Color, Fixation_Rect(2,:));
                Screen('FillRect', Win, [255 255 255]-Parameters.Fixation_Color, InsetRect(Fixation_Rect(1,:),round(Parameters.Fixation_Width./3),round(Parameters.Fixation_Width./3)));
                Screen('FillRect', Win, [255 255 255]-Parameters.Fixation_Color, InsetRect(Fixation_Rect(2,:),round(Parameters.Fixation_Width./3),round(Parameters.Fixation_Width./3)));
                % flip screen
                Screen('Flip', Win);
                if ~t_on && t_off   % if trial is marked as not started, and the previous trial is finished (or this is the first trial)
                    if is_event     % if event is true
                        EventTimeStamps = [EventTimeStamps;elapsedSec]; % append current elapsed time;
                    end
                    TrialOnset = [TrialOnset; elapsedSec];  % append current elapsed time as trial onset time
                    TrialImage = [TrialImage; Parameters.Stim_FileName(ImgIdx(1,1),ImgIdx(1,2))];   % append current image file name
                    t_on = true;    % trial started
                    t_off = false;  % trial not finished 
                end
            else % ISI
                % draw fixation cross
                Screen('FillRect', Win, Parameters.Fixation_Color,Fixation_Rect(1,:));
                Screen('FillRect', Win, Parameters.Fixation_Color, Fixation_Rect(2,:));
                Screen('FillRect', Win, [255 255 255]-Parameters.Fixation_Color, InsetRect(Fixation_Rect(1,:),round(Parameters.Fixation_Width./3),round(Parameters.Fixation_Width./3)));
                Screen('FillRect', Win, [255 255 255]-Parameters.Fixation_Color, InsetRect(Fixation_Rect(2,:),round(Parameters.Fixation_Width./3),round(Parameters.Fixation_Width./3)));
                % flip screen
                Screen('Flip', Win);
                if t_on % if trial begun
                    t_off = true;   % trial finished
                    t_on = false;   % next trial not started
                end
            end
        else % during interblock fixation
            % draw fixation cross
            Screen('FillRect', Win, Parameters.Fixation_Color,Fixation_Rect(1,:));
            Screen('FillRect', Win, Parameters.Fixation_Color, Fixation_Rect(2,:));
            Screen('FillRect', Win, [255 255 255]-Parameters.Fixation_Color, InsetRect(Fixation_Rect(1,:),round(Parameters.Fixation_Width./3),round(Parameters.Fixation_Width./3)));
            Screen('FillRect', Win, [255 255 255]-Parameters.Fixation_Color, InsetRect(Fixation_Rect(2,:),round(Parameters.Fixation_Width./3),round(Parameters.Fixation_Width./3)));
            % flip screen
            Screen('Flip', Win);
        end
    elseif elapsedSec < (Parameters.Preblock_Duration  + totalBlockTime + Parameters.Postblock_Duration) % final fixation
        %draw fixation cross
        Screen('FillRect', Win, Parameters.Fixation_Color,Fixation_Rect(1,:));
        Screen('FillRect', Win, Parameters.Fixation_Color, Fixation_Rect(2,:));
        Screen('FillRect', Win, [255 255 255]-Parameters.Fixation_Color, InsetRect(Fixation_Rect(1,:),round(Parameters.Fixation_Width./3),round(Parameters.Fixation_Width./3)));
        Screen('FillRect', Win, [255 255 255]-Parameters.Fixation_Color, InsetRect(Fixation_Rect(2,:),round(Parameters.Fixation_Width./3),round(Parameters.Fixation_Width./3)));
        % flip screen
        Screen('Flip', Win);
    else % all is over
        RUN_DONE = true;
    end
    
    % check whether the refractory period of key press has passed (300 ms)
    if k && GetSecs-KeyTime >= 0.3
        k = false;
    end
    
    % check for behavioural response
    if ~k
        [Keypr KeyTime Key] = KbCheck(-1);
        if Keypr
            if sum(Key(KeyCodes.Response)) % 1,2,3,4,5
                k = true;   % toggled
                Behaviour.Response = [Behaviour.Response;find(Key,1,'last')]; % log the last key
                Behaviour.ResponseTime = [Behaviour.ResponseTime; KeyTime - Start_of_Expmt]; % log elapsed time
            end
        end
    end
    
    % abort if Escape was pressed
    if find(Key) == KeyCodes.Escape
        Is_Aborted = true;
    end
end

%% Updates variables
End_of_Expmt = GetSecs; % clock the time
Parameters.Is_Aborted = Is_Aborted; % is aborted?
Behaviour.EventTimeStamps = EventTimeStamps;
TrialOutput.Behaviour = Behaviour;
TrialOutput.TrialOnset = TrialOnset;
TrialOutput.TrialImage = TrialImage;
Results.TrialOutput = TrialOutput;
Results.Parameters = Parameters;

%% Save results
% give a warning!
Screen('TextFont', Win, Parameters.FontName);
Screen('TextSize', Win, Parameters.FontSize);
Parameters = rmfield(Parameters, 'Stimulus');  % Remove stimulus from data
Screen('FillRect', Win, Parameters.Background, Parameters.Rect);
DrawFormattedText(Win, 'Saving data...', 'center', 'center', Parameters.Foreground);
Screen('Flip', Win);
% save!
if Is_Aborted
    save(['results' filesep '_aborted_' Parameters.Session_name],'Results');
    new_line;
    disp('Experiment aborted by user!');
    new_line;
else
    save(['results' filesep Parameters.Session_name],'Results');
end

%% Experiment duration
% how long?
new_line;
ExpmtDur = End_of_Expmt - Start_of_Expmt;
ExpmtDurMin = floor(ExpmtDur/60);
ExpmtDurSec = mod(ExpmtDur, 60);
disp(['Experiment lasted ' num2str(ExpmtDurMin) ' minutes, ' num2str(ExpmtDurSec) ' seconds']);
% how many events and responses?
disp(['There were ' num2str(length(EventTimeStamps)) ' dimming events.']);
if isfield(Parameters, 'Event_Chars')
    disp(['The event string was: ' Event_String]);
    Sequence = Event_String(ismember(Event_String, '123456789'));
    disp(['The target sequence was: ' Sequence]);
    disp(['The target sum was: ' num2str(sumdigits(Sequence))]);
else
    disp(['There were ' num2str(length(Behaviour.ResponseTime)) ' button presses.']);
end
new_line;
