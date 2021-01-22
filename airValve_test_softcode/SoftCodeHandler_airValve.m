function SoftCodeHandler_airValve

clear a;
a= arduino();

%% Set up 
configurePin(a, 'D7', 'DigitalOutput');

writeDigitalPin(a, 'D7', 0); %open 
pause(1);
writeDigitalPin(a, 'D7', 1); %close 






SessionData.RawEvents.Trial{1,1}.States.TimeForResponse
lenght(SessionData.RawEvents.Trial{1,1}.Events.Port1In)
Port1Value= false;
for i = 1:length(SessionData.RawEvents.Trial{1,1}.Events.Port1In)
    if SessionData.RawEvents.Trial{1,1}.Events.Port1In(i) > SessionData.RawEvents.Trial{1,1}.States.TimeForResponse(1) && SessionData.RawEvents.Trial{1,1}.Events.Port1In(i) < SessionData.RawEvents.Trial{1,1}.States.TimeForResponse(2)
        Port1Value= true;
    end
end