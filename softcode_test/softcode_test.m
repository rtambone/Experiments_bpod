function softcode_test
global BpodSystem
 
%% Setup (runs once before the first trial)
S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'

if isempty(fieldnames(S))
    S.GUI.MaxTrials = 200;
    S.GUI.InterTrialIntervalMean = 2;
end
TrialTypes= ceil(rand(1, S.GUI.MaxTrials)*7);
iti= 2

%% Main loop
for currentTrial = 1: S.GUI.MaxTrials
    %LoadSerialMessages('SoftCode', {['B' 1], ['B' 2], ['B' 4], ['B' 8], ['B' 16], ['B' 32], ['B' 64], ['B' 128], ['B' 0]});
    StopStimulusOutput= {'SoftCode', 9};   % close all the valves
    S= BpodParameterGUI('sync',S);
    
    % Tial-specific state matrix
    switch TrialTypes(currentTrial)
        case 1  
            StimulusArgument= {'SoftCode', 1};
        case 2  
            StimulusArgument= {'SoftCode', 2};
        case 3  
            StimulusArgument= {'SoftCode', 3};
        case 4  
            StimulusArgument= {'SoftCode', 4};
        case 5 
            StimulusArgument= {'SoftCode', 5};
        case 6  
            StimulusArgument= {'SoftCode', 6};
        case 7
            StimulusArgument= {'SoftCode', 7};
        case 8
            StimulusArgument= {'SoftCode', 8};  
    end
    
    % States definition
    sma= NewStateMachine();
    sma= AddState(sma, 'Name', 'PreStimulus',...
        'Timer', 1,...
        'StateChangeCondition', {'Tup','DeliverStimulus'},...
        'OutputActions', StimulusArgument);
    
    sma= AddState(sma, 'Name', 'DeliverStimulus',...
        'Timer', 2,...
        'StateChangeCondition', {'Tup','StopStimulus'},...
        'OutputActions', StimulusArgument);
        
    sma= AddState(sma, 'Name', 'StopStimulus',...
        'Timer', 0,...
        'StateChangeCondition', {'Tup','InterTrialInterval'},...
        'OutputActions', StopStimulusOutput);
        
    sma= AddState(sma, 'Name', 'InterTrialInterval',...
        'Timer', iti, ...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {});
    SendStateMatrix(sma);
    RawEvents= RunStateMatrix;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned (i.e. if not final trial, interrupted by user)
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
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
end