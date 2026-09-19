"""Check a compiled sideload artifact, not just an archive renamed to IPA."""
import pathlib, plistlib, struct, sys, zipfile

def verify_device_macho(data, label):
    assert data[:4] == b'\xcf\xfa\xed\xfe', f'{label}: not thin 64-bit little-endian Mach-O'
    cpu, subtype, filetype, ncmds = struct.unpack_from('<IIII', data, 4)
    assert cpu == 0x0100000c, f'{label}: not ARM64'
    offset = 32
    platforms = []
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', data, offset)
        assert size >= 8 and offset + size <= len(data)
        if cmd == 0x32:  # LC_BUILD_VERSION: 2=iOS device, 7=iOS simulator.
            platforms.append(struct.unpack_from('<I', data, offset + 8)[0])
        offset += size
    assert platforms and set(platforms) == {2}, f'{label}: not iOS device: {platforms}'

p=pathlib.Path(sys.argv[1])
with zipfile.ZipFile(p) as z:
    names=set(z.namelist())
    base='Payload/Runner.app/'
    for path in ['Info.plist', 'Runner', 'Frameworks/App.framework/App', 'ru.lproj/InfoPlist.strings']:
        assert base+path in names, f'Missing {path}'
    assert z.testzip() is None, 'ZIP CRC failure'
    info=plistlib.loads(z.read(base+'Info.plist'))
    assert info['CFBundleExecutable']=='Runner'
    assert info.get('MinimumOSVersion'), 'Missing iOS requirement'
    assert info.get('DTPlatformName') == 'iphoneos', 'Not an iOS device build'
    assert info.get('CFBundleSupportedPlatforms') == ['iPhoneOS']
    assert not any(n.startswith(base+'Watch/') for n in names)
    verify_device_macho(z.read(base+'Runner'), 'Runner')
    verify_device_macho(z.read(base+'Frameworks/App.framework/App'), 'Flutter AOT')
    print('ZIP CRC: OK; Runner and Flutter AOT: ARM64/iOS device; Russian iOS strings: present')
    print('Bundle:',info['CFBundleIdentifier'],'version:',info['CFBundleShortVersionString'],'min iOS:',info['MinimumOSVersion'])
    print('Unsigned sideload package; on-device signing and hardware behavior NOT verified.')
