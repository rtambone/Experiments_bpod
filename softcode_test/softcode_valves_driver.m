function softcode_valve_driver(Byte)

global BpodSystem

valve_drive= serialport('COMX', 1312500);   %initialize serial port 
messages={['B',1], ['B' 2], ['B' 4], ['B' 8], ['B' 16], ['B' 32], ['B' 64], ['B' 128], ['B' 0]};

fopen(valve_drive);
switch Byte
    case 1
        fwrite(valve_drive, ['B' 1]);
    case 2
        fwrite(valve_drive, ['B' 2]);
    case 3
        fwrite(valve_drive, ['B' 4]);
    case 4
        fwrite(valve_drive, ['B' 8]);
    case 5
        fwrite(valve_drive, ['B' 16]);
    case 6
        fwrite(valve_drive, ['B' 32]);
    case 7
        fwrite(valve_drive, ['B' 64]);
    case 8
        fwrite(valve_drive, ['B' 128]);
    case 9
        fwrite(valve_drive, ['B' 0]);

fclose(valve_drive);
end