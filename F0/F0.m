% F0: Familiarization with reward spout. Intermittent reward. It works kinda like a click-training. 
% Use until the mouse gets 750 µl of reward and for no longer than 30'.
% I run it in two consecutive blocks. In the first block the spout is 'pushed
% against' the mouse's mouth. In the second block, the spout is positioned
% at the final position.

function F0

global BpodSystem %This makes the BpodSystem object visible in the protocol function's workspace

%% Setup (runs once before the first trial)
%When you launch a protocol from the launch manager, you can select a settings file.
%The settings file is simply a .mat file containing a parameter struct like the one above, which will be stored in BpodSystem.ProtocolSettings.
S = BpodSystem.ProtocolSettings;

%If the setting file is empty use these default parameters
if isempty(fieldnames(S))
    S.GUI.RewardAmount = 5;
    S.GUI.MaxTrials = 200;
    S.GUI.InterTrialIntervalMean = 2;
end

ValveTime = GetValveTimes(S.GUI.RewardAmount, 1); % Return the valve-open duration in seconds for valve 1

TotalRewardDisplay('init'); % Total Reward display (online display of the total amount of liquid reward earned)
BpodNotebook('init'); % Launches an interface to write notes about behavior and manually score trials
BpodParameterGUI('init', S); %Initialize the Parameter GUI plugin

%% Main loop (runs once per trial)
for currentTrial = 1 : S.GUI.MaxTrials
    inter_trial_interval = exprnd(S.GUI.InterTrialIntervalMean) + S.GUI.InterTrialIntervalMean;
    while inter_trial_interval > 10
        inter_trial_interval = exprnd(S.GUI.InterTrialIntervalMean) + S.GUI.InterTrialIntervalMean;
    end
    inter_trial_interval = ceil(inter_trial_interval);
    RewardOutput = {'PWM1', 155, 'ValveState', 1};
    S = BpodParameterGUI('sync', S);
    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'WaitForStart', ...
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'Reward'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'DrinkingGrace'},...
        'OutputActions', RewardOutput);
    sma = AddState(sma, 'Name', 'DrinkingGrace', ...
        'Timer', 3,...
        'StateChangeConditions', {'Tup', 'InterTrialDelay'},...
        'OutputActions', {});
        sma = AddState(sma, 'Name', 'InterTrialDelay', ...
        'Timer', inter_trial_interval,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {});
    SendStateMatrix(sma); %Send the state matrix to the Bpod device
    RawEvents = RunStateMatrix; %Run the trial's finite state machine, and return the measured timecourse of events and states. The flow of states will be controlled by the Bpod device until the trial is complete (but see soft codes)
    if ~isempty(fieldnames(RawEvents)) % If trial data was returnedBpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents); %Add this trial's raw data to a human-readable data struct. The data struct, BpodSystem.Data, will later be saved to the current data file (automatically created based on your launch manager selections and the current time).
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); %If you are using plugins that can add data to the data struct, call their update methods.
        BpodSystem.Data.TrialSettings(currentTrial) = S; %Add a snapshot of the current settings struct, for a record of the parameters used for the current trial.
        UpdateTotalRewardDisplay(S.GUI.RewardAmount, currentTrial);
        SaveBpodSessionData; %Save the data struct to the current data file.
    end
    HandlePauseCondition; %If the user has pressed the "Pause" button on the Bpod console, wait here until the session is resumed
    if BpodSystem.Status.BeingUsed == 0 %If the user has ended the session from the Bpod console, exit the loop.
        clear A
        return
    end
end

function UpdateTotalRewardDisplay(RewardAmount, currentTrial)
% If rewarded based on the state data, update the TotalRewardDisplay
global BpodSystem
if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
    TotalRewardDisplay('add', RewardAmount);
end