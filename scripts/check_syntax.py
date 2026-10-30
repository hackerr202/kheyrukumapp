import os
import sys

def check_brackets(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    stack = []
    in_string = False
    string_char = None
    in_multiline = False
    in_line_comment = False
    in_block_comment = False
    
    i = 0
    line = 1
    col = 1
    errors = []
    
    while i < len(content):
        c = content[i]
        
        if c == '\n':
            line += 1
            col = 1
            in_line_comment = False
            i += 1
            continue
            
        if in_line_comment:
            i += 1
            col += 1
            continue
            
        if in_block_comment:
            if content[i:i+2] == '*/':
                in_block_comment = False
                i += 2
                col += 2
                continue
            i += 1
            col += 1
            continue
            
        if in_multiline:
            if content[i:i+3] == string_char * 3:
                in_multiline = False
                i += 3
                col += 3
                continue
            i += 1
            col += 1
            continue
            
        if in_string:
            if c == '\\':
                i += 2
                col += 2
                continue
            if c == string_char:
                in_string = False
                i += 1
                col += 1
                continue
            i += 1
            col += 1
            continue
            
        # check comments
        if content[i:i+2] == '//':
            in_line_comment = True
            i += 2
            col += 2
            continue
        if content[i:i+2] == '/*':
            in_block_comment = True
            i += 2
            col += 2
            continue
            
        # check strings
        if content[i:i+3] in ("'''", '"""'):
            in_multiline = True
            string_char = content[i]
            i += 3
            col += 3
            continue
        if c in ("'", '"'):
            in_string = True
            string_char = c
            i += 1
            col += 1
            continue
            
        # check brackets
        if c in '({[':
            stack.append((c, line, col))
        elif c in ')}]':
            matching = {'(': ')', '{': '}', '[': ']'}
            if not stack:
                errors.append(f'Unmatched closing {c} at {line}:{col}')
            else:
                top, t_line, t_col = stack.pop()
                if matching[top] != c:
                    errors.append(f'Mismatched {top} ({t_line}:{t_col}) with {c} ({line}:{col})')
                    
        i += 1
        col += 1
        
    for top, t_line, t_col in stack:
        errors.append(f'Unclosed {top} from {t_line}:{t_col}')
        
    return errors

if __name__ == '__main__':
    files = [
        'lib/core/services/student_service.dart',
        'lib/core/services/halaqah_service.dart',
        'lib/core/services/announcement_service.dart',
        'lib/widgets/add_student_dialog.dart',
        'lib/screens/dashboard/tabs/messages_tab.dart',
        'lib/screens/dashboard/tabs/home_tab.dart',
        'lib/core/theme/app_theme.dart',
    ]

    all_passed = True
    for f in files:
        if not os.path.exists(f):
            print(f'File missing: {f}')
            all_passed = False
            continue
        errs = check_brackets(f)
        if errs:
            print(f'{f}: [FAIL] ({len(errs)} errors)')
            for e in errs[:5]:
                print('  ', e)
            all_passed = False
        else:
            print(f'{f}: [PASS]')

    sys.exit(0 if all_passed else 1)
