function GNG_exporative_noTrialManager
global BpodSystem

%% Setup (runs once before the first trial)
S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'

if isempty(fieldnames(S))  % If chosen settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount= 3; 
    S.GUI.PreStimulusDuration= 3; 
    S.GUI.StimulusDuration= 2; 
    S.GUI.TimeForResponseDuration= 2;
    S.GUI.NothingTimeDuration= 2;
    S.GUI.TimeOutDuration= 9;
    S.GUI.MaxTrials= 300;   
end

%--- Define trials structure
TrialTypes= [];
for el= 1:61
   TrialTypes= [TrialTypes 1];
   TrialTypes= [TrialTypes 3];
end
for el= 1:7
   TrialTypes= [TrialTypes 2];
   TrialTypes= [TrialTypes 4];
end
for el= 1:67
   TrialTypes= [TrialTypes 5];
   TrialTypes= [TrialTypes 6];
end
for el= 1:30
    TrialTypes= [TrialTypes 7];
end   
TrialTypes= Shuffle(TrialTypes);   
BpodSystem.Data.TrialTypes= [];     % for storing trials completed 

% InterTialInterval distribution
pd= makedist('Uniform', 'Lower', 3, 'Upper', 6);
inter_trials_intervals= random(pd, 1, S.GUI.MaxTrials);

%--- Initialize plots
TotalRewardDisplay('init'); % Total Reward display (online display of the total amount of liquid reward earned)
BpodNotebook('init'); % Launches an interface to write notes about behavior and manually score trials
BpodParameterGUI('init', S); %Initialize the Parameter GUI plugin
BpodSystem.ProtocolFigures.TrialTypeOutcomePlotFig = figure('Position', [50 440 1000 370],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.TrialTypeOutcomePlot = axes('Position', [.075 .35 .89 .55]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.TrialTypeOutcomePlot, 'init', TrialTypes);
% PerformancePlot('init', {1, 2}, {'go', 'nogo'})

%% Main loop 
for currentTrial = 1: S.GUI.MaxTrials
    LoadSerialMessages('ValveModule1', {['B' 1], ['B' 2], ['B' 4], ['B' 8], ['B' 16], ['B' 32], ['B' 64], ['B' 128], ['B' 0]});
    RewardOutput= {'ValveState',1}; % open water valve
    StopStimulusOutput= {'ValveModule1', 9};   % close all the valves
    ValveTime= GetValveTimes(S.GUI.RewardAmount, 1);
    S= BpodParameterGUI('sync',S);
    
    % Tial-specific state matrix 
    switch TrialTypes(currentTrial)
        % CS(+)
        case 1  % O1 rewarded
            StimulusArgument= {'ValveModule1', 1}; 
            LickActionState= 'Reward';
            NoLickActionState= 'InterTrialInterval';
        case 2  % O1 nothing
            StimulusArgument= {'ValveModule1', 1};
            LickActionState= 'Nothing'; 
            NoLickActionState= 'InterTrialInterval';
        case 3  % O2 rewarded
            StimulusArgument= {'ValveModule1', 2}; 
            LickActionState= 'Reward';
            NoLickActionState= 'InterTrialInterval';
        case 4  % O2 nothing
            StimulusArgument= {'ValveModule1', 2};
            LickActionState= 'Nothing';  
            NoLickActionState= 'InterTrialInterval';
        % Cs(N)
        case 5
            StimulusArgument= {'ValveModule1', 3};
            LickActionState= 'Nothing';
            NoLickActionState= 'Nothing';
        case 6
            StimulusArgument= {'ValveModule1', 4};
            LickActionState= 'Nothing'; 
            NoLickActionState= 'Nothing';
        % Us
        case 7 
            StimulusArgument= {};
            LickActionState= 'Reward'; 
            NoLickActionState= 'Reward'; 
    end
    
    % States definition 
    sma= NewStateMachine(); 
    sma= AddState(sma, 'Name', 'PreStimulus',...
        'Timer', S.GUI.PreStimulusDuration,...
        'StateChangeCondition', {'Tup','DeliverStimulus'},...
        'OutputActions', {});  

    sma= AddState(sma, 'Name', 'DeliverStimulus',...
        'Timer', S.GUI.StimulusDuration,...
        'StateChangeCondition', {'Tup','StopStimulus'},...
        'OutputActions', StimulusArgument); 

    sma= AddState(sma, 'Name', 'StopStimulus',...
        'Timer', 0,...
        'StateChangeCondition', {'Tup','TimeForResponse'},...
        'OutputActions', StopStimulusOutput); 

    sma= AddState(sma, 'Name', 'TimeForResponse',...
        'Timer', S.GUI.TimeForResponseDuration,...
        'StateChangeCondition', {'Tup', NoLickActionState, 'Port1In', LickActionState},...
        'OutputActions', {});

    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'DrinkingGrace'},...
        'OutputActions', RewardOutput);

    sma = AddState(sma, 'Name', 'DrinkingGrace', ...
        'Timer', S.GUI.DrinkingGraceDuration,...
        'StateChangeConditions', {'Tup', 'InterTrialInterval'},...
        'OutputActions', {});

    sma = AddState(sma, 'Name', 'Nothing', ...
        'Timer', S.GUI.NothingTimeDuration,...
        'StateChangeConditions', {'Tup', 'InterTrialInterval'},...
        'OutputActions', {});

    sma= AddState(sma, 'Name', 'InterTrialInterval',...
        'Timer', inter_trials_intervals(currentTrial), ...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {});
    SendStateMatrix(sma);
    RawEvents= RunStateMatrix; 
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned (i.e. if not final trial, interrupted by user)
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        UpdateTrialTypeOutcomePlot(TrialTypes, BpodSystem.Data);
        UpdateTotalRewardDisplay(S.GUI.RewardAmount, currentTrial);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end     
    HandlePauseCondition;
    if BpodSystem.Status.BeingUsed == 0
        Obj= ValveDriverModule('COM4');   %%% 
        for idx= 1:8
            closeValve(Obj, idx)
        end
        return;
    end
end 


% -1: error, unpunished (unfilled red circle)
% 0: error, punished (filled red circle)
% 1: correct, rewarded (filled green circle)
% 2: correct, unrewarded (unfilled green circle)
% 3: no response (unfilled black circle)
function UpdateTrialTypeOutcomePlot(TrialTypes, Data)
% Determine outcomes from state data and score as the SideOutcomePlot plugin expects
% global BpodSystem
Outcomes = NaN(1,Data.nTrials);
Port1values= zeros(1, Data.nTrials);
for x = 1:Data.nTrials
    if isfield(Data.RawEvents.Trial{x}.Events, 'Port1In') 
        for i = 1:length(Data.RawEvents.Trial{x}.Events.Port1In) % for every timestamps of port1in check if it happened during the time window for response 
            if Data.RawEvents.Trial{x}.Events.Port1In(i) > Data.RawEvents.Trial{x}.States.TimeForResponse(1) && Data.RawEvents.Trial{x}.Events.Port1In(i) < Data.RawEvents.Trial{x}.States.TimeForResponse(2)
                Port1values(x)= 1;
            end
        end
    end    
    if TrialTypes(x) == 1 || 3 % go rewarding trials 
        if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
            Outcomes(x) = 1; % licked and rewarded
        else 
            Outcomes(x) = -1; % not licked
        end
    elseif TrialTypes(x) == 2 || 4 % go not-rewarding trials
        if Port1values(x) == 1 
            Outcomes(x) = 2; % licked not reward
        else 
            Outcomes(x) = -1; % not licked but it should have 
        end
    elseif TrialTypes(x) == 5 || 6 % nothing trials
        if Port1values(x) == 1
            Outcomes(x) = -1; % licked 
        else 
            Outcomes(x) = 2; % not licked 
        end
    end    
end
TrialTypeOutcomePlot(BpodSystem.GUIHandles.TrialTypeOutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes);
end

function UpdateTotalRewardDisplay(RewardAmount, currentTrial)
% If rewarded based on the state data, update the TotalRewardDisplay
% global BpodSystem
if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
    TotalRewardDisplay('add', RewardAmount);
end
end
end