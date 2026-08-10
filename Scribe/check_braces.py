import sys

def check_braces(filename):
    with open(filename, 'r') as f:
        content = f.read()

    lines = content.split('\n')
    stack = []
    
    for i, line in enumerate(lines):
        for j, char in enumerate(line):
            if char == '{':
                stack.append((i+1, j+1))
            elif char == '}':
                if not stack:
                    print(f"Error: Unmatched '}}' at line {i+1}, col {j+1}")
                    return
                stack.pop()
                
    if stack:
        print("Error: Unmatched '{' at:")
        for line, col in stack:
            print(f"  Line {line}, col {col}")
    else:
        print("All braces are balanced.")

if __name__ == "__main__":
    check_braces(sys.argv[1])
