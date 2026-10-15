"""Strip full-line comments, blank lines and indentation from a .mm script so
it fits M5's 128 KB code limit. Usage: python minify_mm.py <in.mm> <out.mm>"""
import sys
src = open(sys.argv[1], encoding='utf-8').read().split('\n')
out = []
for line in src:
    t = line.strip()
    if not t or t.startswith('//'):
        continue
    out.append(t)
open(sys.argv[2], 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
print(len('\n'.join(out).encode('utf-8')), 'bytes')
