function SoftCodeHandler_airValve

clear a;
a= arduino();

%% Set up 
configurePin(a, 'D7', 'DigitalOutput');

writeDigitalPin(a, 'D7', 0); %open 
pause(1);
writeDigitalPin(a, 'D7', 1); %close 