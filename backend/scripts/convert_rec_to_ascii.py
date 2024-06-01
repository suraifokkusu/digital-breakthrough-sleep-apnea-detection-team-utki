import numpy as np
import pyedflib
import subprocess
import sys
import os

def install(package):
    subprocess.check_call([sys.executable, "-m", "pip", "install", package])

try:
    import numpy as np
    import pyedflib
except ImportError:
    install('numpy')
    install('pyedflib')
    import numpy as np
    import pyedflib

def calculate_physical_values(digital_values, digital_min, digital_max, physical_min, physical_max):
    scale_factor = (physical_max - physical_min) / (digital_max - digital_min)
    offset = physical_min
    physical_values = scale_factor * (digital_values - digital_min) + offset
    return physical_values

def convert_rec_to_ascii(rec_file, ascii_file, channel_number):
    try:
        if not os.path.isfile(rec_file):
            raise FileNotFoundError(f"Input file {rec_file} not found.")

        # Открываем исправленный .rec файл как EDF
        edf_reader = pyedflib.EdfReader(rec_file)

        # Проверяем количество каналов
        n_channels = edf_reader.signals_in_file
        if channel_number < 0 or channel_number >= n_channels:
            raise ValueError(f"Invalid channel number {channel_number}. Should be between 0 and {n_channels-1}.")

        # Извлекаем данные выбранного канала
        signal = edf_reader.readSignal(channel_number)

        # Извлекаем параметры из заголовка
        digital_min = edf_reader.getPhysicalMinimum(channel_number)
        digital_max = edf_reader.getPhysicalMaximum(channel_number)
        physical_min = edf_reader.getDigitalMinimum(channel_number)
        physical_max = edf_reader.getDigitalMaximum(channel_number)

        print(f"Converting digital values to physical values with min/max: digi_min={digital_min}, digi_max={digital_max}, phys_min={physical_min}, phys_max={physical_max}")

        # Преобразуем цифровые значения в физические
        physical_values = calculate_physical_values(signal, digital_min, digital_max, physical_min, physical_max)

        # Закрываем файл
        edf_reader.close()

        # Преобразуем сигнал в формат ASCII
        with open(ascii_file, 'w') as f:
            for value in physical_values:
                f.write(f"{value}\n")

        print(f"Successfully converted channel {channel_number} of {rec_file} to {ascii_file}.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python convert_rec_to_ascii.py <input.rec> <output.ascii> <channel_number>")
        sys.exit(1)

    rec_file = sys.argv[1]
    ascii_file = sys.argv[2]
    channel_number = int(sys.argv[3])

    print(f"Converting {rec_file} to {ascii_file} on channel {channel_number}")
    convert_rec_to_ascii(rec_file, ascii_file, channel_number)
