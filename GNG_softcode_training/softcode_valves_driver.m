function softcode_valve_driver(Byte)

global BpodSystem

valve_drive= serialport('COM7', 1312500);   %initialize serial port 

switch Byte
    case 1
        write(valve_drive, ['B' 1], 'uint8');
    case 2
        write(valve_drive, ['B' 2], 'uint8');
    case 3
        write(valve_drive, ['B' 4], 'uint8');
    case 4
        write(valve_drive, ['B' 8], 'uint8');
    case 5
        write(valve_drive, ['B' 16], 'uint8');
    case 6
        write(valve_drive, ['B' 32], 'uint8');
    case 7
        write(valve_drive, ['B' 64], 'uint8');
    case 8
        write(valve_drive, ['B' 128], 'uint8');
    case 9
        write(valve_drive, ['B' 0], 'uint8');
end
end