function airValve_test        

global BpodSystem

%% Setup (runs once before the first trial)
S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'

if isempty(fieldnames(S))  % If chosen settings file was an empty struct, populate struct with default settings
    S.GUI.OpenDuration= 5; 
    S.GUI.PreStimulusDuration= 0.5;
end

%--- Initialize plots
BpodNotebook('init'); % Launches an interface to write notes about behavior and manually score trials

%--- Initialize port
arduinoPort= ArCOMObject('COM3', 115200)    % Second argument is baud rate (same of arduino sketch)

%--- Define trials structure
MaxTrials= 200;     % there are 8 trial types, so on avarage 100 trials per types
TrialTypes= ones(1,MaxTrials);
BpodSystem.Data.TrialTypes= [];     % for storing trail completed 

%% Start first trial 
sma= PrepareStateMachine(S, TrialTypes, 1, []); % trial 1 and empty currentEvents
TrialManager.startTrial(sma); 

%% Start successive trials
for currentTrial = 1:MaxTrials
    currentTrialEvents= TrialManager.getCurrentEvents({'Reward','TimeOutState','Punish'});
    % bpod waits until enters one of the listed trigger state, then returns
    % current trial's states visisted + events captured to this point 
    
    if BpodSystem.Status.BeingUsed == 0
        O= ValveDriverModule('');   %%% 
        for idx= 1:8
            closeValve(0, idx)
        end
        return;
    end     % if user hit console stop button, end session
    
    [sma, S]= PrepareStateMachine(S, TrialTypes, currentTrial+1, currentTrialEvents);
    % this prepares the next state machine 
    % this function has a separate workspace, so pass any local variable
    % needed to make the state machine as fields of settings struct S
    
    SendStateMachine(sma, 'RunASAP'); 
    
    RawEvents= TrialManager.getTrialData;
    % hang here until trial is over, then retrives full trial's raw data
    
    if BpodSystem.Status.BeingUsed == 0
        O= ValveDriverModule('');   %%% 
        for idx= 1:8
            closeValve(0, idx)
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
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end   
end
end

function [sma, S]= PrepareStateMachine(S, TrialTypes, currentTrial, currentTrialEvents)
% in this case we don't need trial events to build the state machine, but
% they are available in currentTrialEvents

S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin

% Tial-specific state matrix 
sma= NewStateMachine(); 
sma= AddState(sma, 'Name', 'PreStimulus',...
    'Timer', S.GUI.PreStimulusDuration,...
    'StateChangeCondition', {'Tup','OpenAirValve'},...
    'OutputActions', {}); 

sma= AddState(sma, 'Name', 'OpenAirValve',...
    'Timer', S.GUI.OpenDuration,...
    'StateChangeCondition', {'Tup',''},...
    'OutputActions', {'AirValveModule',1, 'PWM1',255}); 

sma= AddState(sma, 'Name', 'StopStimulus',...
    'Timer', 0,...
    'StateChangeCondition', {'Tup','>exit'},...
    'OutputActions', {'AirValveModule',0, 'PWM1',1}); 
end    