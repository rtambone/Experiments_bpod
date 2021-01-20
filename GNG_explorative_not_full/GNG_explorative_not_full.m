function GNG_explorative_not_full
global BpodSystem

%% Setup (runs once before the first trial)
S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'

if isempty(fieldnames(S))  % If chosen settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount= 5; 
    S.GUI.PreStimulusDuration= 0.5; 
    S.GUI.StimulusDuration= 1; 
    S.GUI.TimeForResponseDuration= 1;
    S.GUI.NothingTimeDuration= 1;
    S.GUI.DrinkingGraceDuration= 1;
    S.GUI.MaxTrials= 200;   
end

%--- Define trials structure
p=[0.18, 0.02, 0.18, 0.02, 0.2, 0.2, 0.1];
pDist= makedist('Multinomial',p);
TrialTypes= random(pDist, 1, S.GUI.MaxTrials); % draw random numbers from the specified distribution
BpodSystem.Data.TrialTypes= [];     % for storing trials completed 

% InterTialInterval distribution
inter_trials_intervals= zeros(1,S.GUI.MaxTrials); % pre-allocation for speed issues
for i=1:S.GUI.MaxTrials
    ITI= round(exprnd(1)+0.5,2);
    while ITI > 3
        ITI= round(exprnd(1)+0.5,2);
    end
    inter_trials_intervals(i)= ITI;
end

%--- Initialize plots
TotalRewardDisplay('init'); % Total Reward display (online display of the total amount of liquid reward earned)
BpodNotebook('init'); % Launches an interface to write notes about behavior and manually score trials
BpodParameterGUI('init', S); %Initialize the Parameter GUI plugin
BpodSystem.ProtocolFigures.TrialTypeOutcomePlotFig = figure('Position', [50 440 1000 370],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.TrialTypeOutcomePlot = axes('Position', [.075 .35 .89 .55]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.TrialTypeOutcomePlot,'init',TrialTypes);
% PerformancePlot('init', {1, 2}, {'go', 'nogo'})

%% Start first trial 
TrialManager= TrialManagerObject; 
sma= PrepareStateMachine(S, TrialTypes, 1, [], inter_trials_intervals); % trial 1 and empty currentEvents
TrialManager.startTrial(sma); 

%% Start successive trials
for currentTrial = 1:S.GUI.MaxTrials
   % currentITI= S.GUI.inter_trials_intervals(currentTrials);
    currentTrialEvents= TrialManager.getCurrentEvents({'Reward','Nothing'});
    % bpod waits until enters one of the listed trigger state, then returns
    % current trial's states visisted + events captured to this point 
    
    if BpodSystem.Status.BeingUsed == 0
        Obj= ValveDriverModule('COM6');   %%% 
        for idx= 1:8
            closeValve(Obj, idx)
        end
        return;
    end     % if user hit console stop button, end session
    
    [sma, S]= PrepareStateMachine(S, TrialTypes, currentTrial+1, currentTrialEvents, inter_trials_intervals);
    % this prepares the next state machine 
    % this function has a separate workspace, so pass any local variable
    % needed to make the state machine as fields of settings struct S
    
    SendStateMachine(sma, 'RunASAP'); 
    
    RawEvents= TrialManager.getTrialData;
    % hang here until trial is over, then retrives full trial's raw data
    
    if BpodSystem.Status.BeingUsed == 0
        Obj= ValveDriverModule('COM6');   %%% 
        for idx= 1:8
            closeValve(Obj, idx)
        end
        return;
    end     % if user hit console stop button, end session
    
    HandlePauseCondition;   
    % checks to see if the protocol is paused, in this case waits until
    % user resumes
    
    TrialManager.startTrial(); 
    % start processing the next trial's event (no arguments since SM was
    % already sent
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned (i.e. if not final trial, interrupted by user)
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
%       UpdatePerformancePlot(TrialTypes, BpodSystem.Data);
        UpdateTotalRewardDisplay(S.GUI.RewardAmount, currentTrial);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end   
end
end

function [sma, S]= PrepareStateMachine(S, TrialTypes, currentTrial, currentTrialEvents, ITI) % ITI argument for intertrials intervals
% in this case we don't need trial events to build the state machine, but
% they are available in currentTrialEvents

LoadSerialMessages('ValveModule1', {['B' 1], ['B' 2], ['B' 4], ['B' 8], ['B' 16], ['B' 32], ['B' 64], ['B' 128], ['B' 0]});

RewardOutput= {'ValveState',1}; % open water valve
StopStimulusOutput= {'ValveModule1', 9};   % close all the valves
ValveTime= GetValveTimes(S.GUI.RewardAmount, 1);

S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin

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
    'Timer', ITI(currentTrial), ...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions',{});
end       


% -1: error, unpunished (unfilled red circle)
% 0: error, punished (filled red circle)
% 1: correct, rewarded (filled green circle)
% 2: correct, unrewarded (unfilled green circle)
% 3: no response (unfilled black circle)
function UpdateSideOutcomePlot(TrialTypes, Data)
% Determine outcomes from state data and score as the SideOutcomePlot plugin expects
global BpodSystem
Outcomes = NaN(1,Data.nTrials);
for x = 1:Data.nTrials
    if TrialTypes(x) == 1 || 3 % go rewarding trials 
        if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
            Outcomes(x) = 1; % licked and rewarded
        else 
            Outcomes(x) = -1; % not licked
        end
    else
        Outcomes(x) = 3;
    end    
end
TrialTypeOutcomePlot(BpodSystem.GUIHandles.TrialTypeOutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes);
end


% function UpdatePerformancePlot(TrialTypes, Data)
% Outcomes = -ones(1,Data.nTrials);
% for x = 1:Data.nTrials
%     if TrialTypes(x) == 1
%         if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
%             Outcomes(x) = 1;
%         else
%             Outcomes(x) = 0;
%         end
%     end
%     if TrialTypes(x) == 2
%         if ~isnan(Data.RawEvents.Trial{x}.States.Punish(1))
%             Outcomes(x) = 0;
%         else
%             Outcomes(x) = 1;
%         end
%     end
% end
% PerformancePlot('update',TrialTypes,Outcomes,Data.nTrials);
% end

function UpdateTotalRewardDisplay(RewardAmount, currentTrial)
% If rewarded based on the state data, update the TotalRewardDisplay
global BpodSystem
if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
    TotalRewardDisplay('add', RewardAmount);
end
end