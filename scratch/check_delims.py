with open('scripts/quant_levels_engine.mm', 'r', encoding='utf-8') as f:
    text = f.read()

pairs = {'(': ')', '{': '}', '[': ']'}
stack = []
for line_no, line in enumerate(text.splitlines(), 1):
    in_str = False
    str_char = ''
    i = 0
    while i < len(line):
        ch = line[i]
        if in_str:
            if ch == '\\':
                i += 2
                continue
            elif ch == str_char:
                in_str = False
        else:
            if ch == '/' and i + 1 < len(line) and line[i+1] == '/':
                break
            elif ch in ('"', "'"):
                in_str = True
                str_char = ch
            elif ch in pairs.keys():
                stack.append((ch, line_no))
            elif ch in pairs.values():
                if not stack:
                    print(f'Unmatched closing {ch} at line {line_no}')
                    exit(1)
                last_ch, last_line = stack.pop()
                if pairs[last_ch] != ch:
                    print(f'Mismatched {last_ch} (line {last_line}) with {ch} at line {line_no}')
                    exit(1)
        i += 1

if stack:
    print(f'Unclosed {stack[-1][0]} from line {stack[-1][1]}')
else:
    print('Delimiters perfectly balanced!')
