import sys, os

src = sys.argv[1]
dst = sys.argv[2]

data = open(src, 'rb').read()
name = os.path.splitext(os.path.basename(src))[0].replace('-', '_')

cols = 16
rows = ['    ' + ', '.join(f'0x{b:02x}' for b in data[i:i+cols])
        for i in range(0, len(data), cols)]

with open(dst, 'w') as f:
    f.write(f'// Auto-generated from {os.path.basename(src)} -- do not edit\n')
    f.write(f'static const unsigned char {name}[] = {{\n')
    f.write(',\n'.join(rows))
    f.write(f'\n}};\n')
    f.write(f'static const unsigned long {name}_size = {len(data)};\n')
