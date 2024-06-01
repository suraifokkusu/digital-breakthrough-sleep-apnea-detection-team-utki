#!/bin/bash

input_file=$1
output_file=$2
channel_number=$3

# Ensure the fixed directory exists
fixed_dir="../uploads/fixed"
mkdir -p $fixed_dir

# Repair the header of the input file
echo "Fixing header for $input_file"
bash ../scripts/edf-hdr-repair.sh "$input_file"

# Проверяем, существует ли перезаписанный файл
if [ ! -f "$input_file" ]; then
    echo "Error: $input_file was not created."
    exit 1
fi

# Копируем перезаписанный файл в директорию fixed
fixed_input_file="$fixed_dir/fixed_$(basename $input_file)"
echo "Copying fixed file to $fixed_input_file"
cp "$input_file" "$fixed_input_file"

if [ ! -f "$fixed_input_file" ]; then
    echo "Error: $fixed_input_file was not created."
    exit 1
fi

# Run the conversion script
echo "Converting fixed file to ASCII: $fixed_input_file"
python3 ../scripts/convert_rec_to_ascii.py "$fixed_input_file" "$output_file" "$channel_number"
