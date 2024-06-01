import subprocess
import sys
import os

def fix_rec_file_with_bash(input_file, output_file):
    script_path = os.path.abspath('./edf-hdr-repair')
    try:
        # Execute the bash script using WSL
        result = subprocess.run(['wsl', 'bash', script_path, input_file, output_file], check=True, text=True, capture_output=True)
        print(f"Fixed header using bash script, output:\n{result.stdout}")
    except subprocess.CalledProcessError as e:
        print(f"Error while fixing header with bash script:\n{e.stderr}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python fix_rec_file.py <input.rec> <output.rec>")
        sys.exit(1)

    input_file = os.path.abspath(sys.argv[1])
    output_file = os.path.abspath(sys.argv[2])
    fix_rec_file_with_bash(input_file, output_file)
