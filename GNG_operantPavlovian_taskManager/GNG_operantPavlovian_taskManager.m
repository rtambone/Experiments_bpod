function GNG_operantPavlovian_taskManager

global BpodSystem %This makes the BpodSystem object visible in the protocol function's workspace




%% Setup (runs once before the first trial)
%When you launch a protocol from the launch manager, you can select a settings file.
%The settings file is simply a .mat file containing a parameter struct like the one above, which will be stored in BpodSystem.ProtocolSettings.
S = BpodSystem.ProtocolSettings;

%If the setting file is empty use these default parameters
if isempty(fieldnames(S))
    S.GUI.RewardAmount = 5;
    S.GUI.PreStimulusDuration = 0.5;
    S.GUI.StimulusDuration = 2; % Seconds  stimulus delivers on each trial
    S.GUI.TimeForResponse = 2; % Seconds after stimulus sampling for a response
    S.GUI.PunishTimeoutDuration = 6; % Seconds to wait on errors before next trial can start
    S.GUI.DrinkingGrace = 1;
    S.GUI.LED_pwm = 0;
end

%% Define trials
MaxTrials = 500;
TrialTypes = ceil(rand(1,MaxTrials)*2);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
%% Initialize plots
LicksPlot('init', getStateColors, getLickColors);
TotalRewardDisplay('init'); % Total Reward display (online display of the total amount of liquid reward earned)
BpodNotebook('init'); % Launches an interface to write notes about behavior and manually score trials
BpodParameterGUI('init', S); %Initialize the Parameter GUI plugin
BpodSystem.ProtocolFigures.TrialTypeOutcomePlotFig = figure('Position', [50 540 1000 220],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.TrialTypeOutcomePlot = axes('Position', [.075 .35 .89 .55]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.TrialTypeOutcomePlot,'init',TrialTypes);
PerformancePlot('init', {[1], [2]}, {'go', 'nogo'})

%% Start first Trial
sma = PrepareStateMachine(S, TrialTypes, 1, []); % Prepare state machine for trial 1 with empty "current events" variable
TrialManager.startTrial(sma); % Sends & starts running first trial's state machine. A MATLAB timer object updates the 
                              % console UI, while code below proceeds in parallel.


%% Start successive trials

for currentTrial = 1 : MaxTrials
    
    currentTrialEvents = TrialManager.getCurrentEvents({'Reward', 'TimeOutState', 'Punish'}); 
                                       % Hangs here until Bpod enters one of the listed trigger states, 
                                       % then returns current trial's states visited + events captured to this point
    
    if BpodSystem.Status.BeingUsed == 0
        O = ValveDriverModule('/dev/cu.usbmodem14101');
        for idx = 1:8
            closeValve(O, idx)
        end
        return;
    end % If user hit console "stop" button, end session
    
    [sma, S] = PrepareStateMachine(S, TrialTypes, currentTrial+1, currentTrialEvents); % Prepare next state machine.
    % Since PrepareStateMachine is a function with a separate workspace, pass any local variables needed to make 
    % the state machine as fields of settings struct S
    
    SendStateMachine(sma, 'RunASAP'); % With TrialManager, you can send the next trial's state machine while the current trial is ongoing
    
    RawEvents = TrialManager.getTrialData; % Hangs here until trial is over, then retrieves full trial's raw data
    
    if BpodSystem.Status.BeingUsed == 0
        O = ValveDriverModule('/dev/cu.usbmodem14101');
        for idx = 1:8
            closeValve(O, idx)
        end
        return;
    end % If user hit console "stop" button, end session
    
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    
    TrialManager.startTrial(); % Start processing the next trial's events (call with no argument since SM was already sent)
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned (i.e. if not final trial, interrupted by user)
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        LicksPlot('update');
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        UpdatePerformancePlot(TrialTypes, BpodSystem.Data);
        UpdateTotalRewardDisplay(S.GUI.RewardAmount, currentTrial);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    
end


function [sma, S] = PrepareStateMachine(S, TrialTypes, currentTrial, currentTrialEvents)
% In this case, we don't need trial events to build the state machine - but
% they are available in currentTrialEvents.
RewardOutput = {'PWM1', S.GUI.LED_pwm, 'ValveState', 1, 'ValveModule1', 9};
PunishOutput = {'ValveModule1', 9};
TimeoutOutput = {'ValveModule1', 9};
ValveTime = GetValveTimes(S.GUI.RewardAmount, 1); % Return the valve-open duration in seconds for valve 1


S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
LoadSerialMessages('ValveModule1', {['B' 1], ['B' 2], ['B' 4], ['B' 8], ['B' 16], ['B' 32], ['B' 64], ['B' 128], ['B' 0]});
switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
    case 1
        StimulusArgument = {'PWM1', S.GUI.LED_pwm, 'ValveModule1', 4};
        LickActionState = 'Reward';
    case 2
        StimulusArgument = {'PWM1', S.GUI.LED_pwm, 'ValveModule1', 5};
        LickActionState = 'Punish';
end
sma = NewStateMatrix(); % Assemble state matrix
sma = AddState(sma, 'Name', 'PreStimulus', ...
    'Timer', S.GUI.PreStimulusDuration,...
    'StateChangeConditions', {'Tup', 'DeliverStimulus'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'DeliverStimulus', ...
    'Timer', S.GUI.StimulusDuration,...
    'StateChangeConditions', {'Tup', 'StopStimulus', 'Port1In', LickActionState},...
    'OutputActions', StimulusArgument);
sma = AddState(sma, 'Name', 'StopStimulus', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'WaitForResponse'},...
    'OutputActions', {'ValveModule1', 9});
sma = AddState(sma, 'Name', 'WaitForResponse', ...
    'Timer', S.GUI.TimeForResponse,...
    'StateChangeConditions', {'Tup', 'TimeOutState', 'Port1In', LickActionState},...
    'OutputActions', {'PWM1', S.GUI.LED_pwm});
sma = AddState(sma, 'Name', 'Reward', ...
    'Timer', ValveTime,...
    'StateChangeConditions', {'Tup', 'Drinking'},...
    'OutputActions', RewardOutput);
sma = AddState(sma, 'Name', 'Drinking', ...
    'Timer', S.GUI.DrinkingGrace,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {'PWM1', S.GUI.LED_pwm});
sma = AddState(sma, 'Name', 'Punish', ...
    'Timer', S.GUI.PunishTimeoutDuration,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', PunishOutput);
sma = AddState(sma, 'Name', 'TimeOutState', ... % Record events while next trial's state machine is sent
    'Timer', 0.25,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', TimeoutOutput);



function UpdateSideOutcomePlot(TrialTypes, Data)
% Determine outcomes from state data and score as the SideOutcomePlot plugin expects
global BpodSystem
Outcomes = NaN(1,Data.nTrials);
for x = 1:Data.nTrials
    if TrialTypes(x) == 1
        if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
            Outcomes(x) = 1;
        else 
            Outcomes(x) = -1;
        end
    end
    if TrialTypes(x) == 2
        if ~isnan(Data.RawEvents.Trial{x}.States.Punish(1))
            Outcomes(x) = 0;
        else 
            Outcomes(x) = -1;
        end
    end
end
TrialTypeOutcomePlot(BpodSystem.GUIHandles.TrialTypeOutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes);

function UpdatePerformancePlot(TrialTypes, Data)
Outcomes = -ones(1,Data.nTrials);
for x = 1:Data.nTrials
    if TrialTypes(x) == 1
        if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
            Outcomes(x) = 1;
        else
            Outcomes(x) = 0;
        end
    end
    if TrialTypes(x) == 2
        if ~isnan(Data.RawEvents.Trial{x}.States.Punish(1))
            Outcomes(x) = 0;
        else
            Outcomes(x) = 1;
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

function state_colors = getStateColors
state_colors = struct( ...
    'DeliverStimulus',[166,206,227]./255,...
    'WaitForResponse',[178,223,138]./255,...
    'Reward',[51,160,44]./255);

function lick_colors = getLickColors
lick_colors = struct( ...
    'Port1In', [228,26,28]./255);