function GNG_softcode_training
global BpodSystem
 
%% Setup (runs once before the first trial)
S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'
 
if isempty(fieldnames(S))  % If chosen settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount= 3;
    S.GUI.PreStimulusDuration = 3;
    S.GUI.StimulusDuration= 2;
    S.GUI.TimeForResponseDuration= 2;
    S.GUI.TimeOut= 9;
    S.GUI.ITImin = 6;
    S.GUI.ITImax = 9;
    S.GUI.MaxTrials= 300;
end
 
%--- Define trials structure
Trials_types= [];   % just the types of the trials
for el= 1:61
   Trials_types= [Trials_types 1];
   Trials_types= [Trials_types 3];
end
for el= 1:7
   Trials_types= [Trials_types 2];
   Trials_types= [Trials_types 4];
end
for el= 1:67
   Trials_types= [Trials_types 5];
   Trials_types= [Trials_types 6];
end
for el= 1:30
    Trials_types= [Trials_types 7];
end
TrialTypes_idx= randperm(S.GUI.MaxTrials); 
TrialTypes= zeros(1,S.GUI.MaxTrials+100);   % the actual trial types to be used in the protocol
for idx = 1:S.GUI.MaxTrials
    TrialTypes(idx)= Trials_types(TrialTypes_idx(idx));
end    
    
    
BpodSystem.Data.TrialTypes= [];     % for storing trials completed 
 
% InterTialInterval distribution
inter_trials_intervals= randi([S.GUI.ITImin - S.GUI.PreStimulusDuration, S.GUI.ITImax - S.GUI.PreStimulusDuration], 1, S.GUI.MaxTrials); 
 
 
%--- Initialize plots
% LicksPlot('init', getStateColors, getLickColors);
TotalRewardDisplay('init'); % Total Reward display (online display of the total amount of liquid reward earned)
BpodNotebook('init'); % Launches an interface to write notes about behavior and manually score trials
BpodParameterGUI('init', S); %Initialize the Parameter GUI plugin
BpodSystem.ProtocolFigures.TrialTypeOutcomePlotFig = figure('Position', [50 440 1000 370],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.TrialTypeOutcomePlot = axes('Position', [.075 .35 .89 .55]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.TrialTypeOutcomePlot, 'init', TrialTypes);
PerformancePlot('init', {[1 2 3 4], [5 6]}, {'go', 'nogo'})
 
%% Main loop
for currentTrial = 1: S.GUI.MaxTrials
    %LoadSerialMessages('SoftCode', {['B' 1], ['B' 2], ['B' 4], ['B' 8], ['B' 16], ['B' 32], ['B' 64], ['B' 128], ['B' 0]});
    RewardOutput= {'ValveState',1}; % open water valve
    StopStimulusOutput= {'ValveModule1', 9};   % close all the valves
    ValveTime= GetValveTimes(S.GUI.RewardAmount, 1);
    S= BpodParameterGUI('sync',S);
    
    % Tial-specific state matrix
    switch TrialTypes(currentTrial)
        % CS+
        case 1  % CS1 rewarded
            StimulusArgument= {'SoftCode', 5};
            LickActionState= 'Reward';
            NoLickActionState= 'TimeOut';
        case 2  % CS1 nothing
            StimulusArgument= {'ValveModule1', 5};
            LickActionState= 'FakeReward';
            NoLickActionState= 'TimeOut';
        case 3  % CS2 rewarded
            StimulusArgument= {'ValveModule1', 2};
            LickActionState= 'Reward';
            NoLickActionState= 'TimeOut';
        case 4  % CS2 nothing
            StimulusArgument= {'ValveModule1', 2};
            LickActionState= 'FakeReward';
            NoLickActionState= 'TimeOut';
            % NS
        case 5  % NS1
            StimulusArgument= {'ValveModule1', 3};
            LickActionState= 'TimeOut';
            NoLickActionState= 'InterTrialInterval';
        case 6  % NS2
            StimulusArgument= {'ValveModule1', 4};
            LickActionState= 'TimeOut';
            NoLickActionState= 'InterTrialInterval';
            % US
        case 7
            StimulusArgument= {};
            LickActionState= 'Reward';
            NoLickActionState= 'Reward';
        case 0
            RunProtocol('Stop');
            
    end
    
    % States definition
    sma= NewStateMachine();
    sma= AddState(sma, 'Name', 'PreStimulus',...
        'Timer', S.GUI.PreStimulusDuration,...
        'StateChangeCondition', {'Tup','DeliverStimulusEarly'},...
        'OutputActions', {});
    
    sma= AddState(sma, 'Name', 'DeliverStimulusEarly',...
        'Timer', S.GUI.StimulusDuration./2,...
        'StateChangeCondition', {'Tup','DeliverStimulusLate'},...
        'OutputActions', StimulusArgument);
    
    sma= AddState(sma, 'Name', 'DeliverStimulusLate',...
        'Timer', S.GUI.StimulusDuration./2,...
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
        'StateChangeConditions', {'Tup', 'InterTrialInterval'},...
        'OutputActions', RewardOutput);
    
    sma = AddState(sma, 'Name', 'FakeReward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'InterTrialInterval'},...
        'OutputActions', {});
    
    sma = AddState(sma, 'Name', 'TimeOut', ...
        'Timer', S.GUI.TimeOut,...
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
%         LicksPlot('update');
        UpdateTrialTypeOutcomePlot(TrialTypes, BpodSystem.Data);
        UpdatePerformancePlot(TrialTypes, BpodSystem.Data);
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
 
 
 
% -1:   miss, punished (red circle)
% 0:    false alarm, punished (red dot)
% 1:    hit, rewarded (green dot)
% 2:    correct rejection, unrewarded (green circle)
% 3:    no response (black circle)
function UpdateTrialTypeOutcomePlot(TrialTypes, Data)
% Determine outcomes from state data and score as the SideOutcomePlot plugin expects
global BpodSystem

Outcomes = nan(1,Data.nTrials);
for x = 1:Data.nTrials
    if TrialTypes(x) == 1 || TrialTypes(x) == 3 % go rewarding trials
        if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
            Outcomes(x) = 1; % licked and rewarded
        else
            Outcomes(x) = -1; % not licked
        end
    end
    if TrialTypes(x) == 2 || TrialTypes(x) ==4 % go not-rewarding trials
        if ~isnan(Data.RawEvents.Trial{x}.States.FakeReward(1))
            Outcomes(x) = 1; % licked not reward
        else
            Outcomes(x) = -1; % not licked but it should have
        end
    end
    if TrialTypes(x) == 5 || TrialTypes(x) ==6 % nothing trials
        if ~isnan(Data.RawEvents.Trial{x}.States.TimeOut(1))
            Outcomes(x) = 0; % licked punished
        else
            Outcomes(x) = 2; % not licked
        end
    end
    if TrialTypes(x) == 7 % nothing trials
        Outcomes(x) = 3; % licked punished
    end
end
BpodSystem.Data.Outcomes.Trial{x} = Outcomes(x);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.TrialTypeOutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes);
 
function UpdatePerformancePlot(TrialTypes, Data)
Outcomes = -ones(1,Data.nTrials);
for x = 1:Data.nTrials
    if TrialTypes(x) == 1 || 3 % go rewarding trials
        if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
            Outcomes(x) = 1; % licked and rewarded
        else
            Outcomes(x) = 0; % not licked
        end
    end
    if TrialTypes(x) == 2 || 4 % go not-rewarding trials
        if ~isnan(Data.RawEvents.Trial{x}.States.FakeReward(1))
            Outcomes(x) = 1; % licked not reward
        else
            Outcomes(x) = 0; % not licked but it should have
        end
    end
    if TrialTypes(x) == 5 || 6 % nothing trials
        if ~isnan(Data.RawEvents.Trial{x}.States.TimeOut(1))
            Outcomes(x) = 0; % licked
        else
            Outcomes(x) = 1; % not licked
        end
    end
end
PerformancePlot('update',TrialTypes,Outcomes,Data.nTrials);
 
function UpdateTotalRewardDisplay(RewardAmount, currentTrial)
% If rewarded based on the state data, update the TotalRewardDisplay
global BpodSystem
if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
    TotalRewardDisplay('add', RewardAmount);
end
 
 
% function state_colors = getStateColors
% state_colors = struct( ...
%     'DeliverStimulus',[166,206,227]./255,...
%     'WaitForResponse',[178,223,138]./255,...
%     'Reward',[51,160,44]./255);
 
% function lick_colors = getLickColors
% lick_colors = struct( ...
%     'Port1In', [228,26,28]./255);